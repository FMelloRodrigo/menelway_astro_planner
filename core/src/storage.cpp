#include "astro/storage.hpp"
#include "astro/target_filter_service.hpp"
#include "astro/ephemeris.hpp"
#include "astro/time.hpp"
#include "sqlite3.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <regex>
#include <sstream>
#include <thread>

namespace astro::storage {

namespace {

struct StmtDeleter {
    void operator()(sqlite3_stmt* stmt) const {
        if (stmt) sqlite3_finalize(stmt);
    }
};
using UniqueStmt = std::unique_ptr<sqlite3_stmt, StmtDeleter>;

catalog::DsoObject row_to_dso(sqlite3_stmt* stmt) {
    catalog::DsoObject obj;
    obj.id = sqlite3_column_int64(stmt, 0);

    const auto* name = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
    if (name) obj.name = name;

    const auto* messier = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
    if (messier) obj.messier = messier;

    const auto* caldwell = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3));
    if (caldwell) obj.caldwell = caldwell;

    const auto* arp = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4));
    if (arp) obj.arp = arp;

    const auto* herschel = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));
    if (herschel) obj.herschel = herschel;

    const auto* ngc_ic = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 6));
    if (ngc_ic) obj.ngc_ic = ngc_ic;

    const auto* cat = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 7));
    if (cat) obj.catalog = cat;

    const auto* cat_num = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 8));
    if (cat_num) obj.catalog_number = cat_num;

    const auto* obj_type = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 9));
    if (obj_type) obj.object_type = obj_type;

    const auto* constel = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 10));
    if (constel) obj.constellation = constel;

    double ra_deg = sqlite3_column_double(stmt, 11);
    double dec_deg = sqlite3_column_double(stmt, 12);
    obj.coordinates.ra = units::degrees_to_hours(units::Degrees{ra_deg});
    obj.coordinates.dec = units::Degrees{dec_deg};

    if (sqlite3_column_type(stmt, 13) != SQLITE_NULL) {
        obj.magnitude = sqlite3_column_double(stmt, 13);
    }
    if (sqlite3_column_type(stmt, 14) != SQLITE_NULL) {
        obj.b_mag = sqlite3_column_double(stmt, 14);
    }
    if (sqlite3_column_type(stmt, 15) != SQLITE_NULL) {
        obj.major_axis_arcmin = sqlite3_column_double(stmt, 15);
    }
    if (sqlite3_column_type(stmt, 16) != SQLITE_NULL) {
        obj.minor_axis_arcmin = sqlite3_column_double(stmt, 16);
    }
    if (sqlite3_column_type(stmt, 17) != SQLITE_NULL) {
        obj.position_angle_deg = sqlite3_column_double(stmt, 17);
    }
    if (sqlite3_column_type(stmt, 18) != SQLITE_NULL) {
        obj.surface_brightness = sqlite3_column_double(stmt, 18);
    }

    const auto* common = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 19));
    if (common) obj.common_names = common;

    const auto* ident = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 20));
    if (ident) obj.identifiers = ident;

    return obj;
}

std::string build_fts_query(const std::string& input) {
    if (input.empty()) return "";

    // Trim leading and trailing whitespace
    size_t start = input.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    size_t end = input.find_last_not_of(" \t\r\n");
    std::string s = input.substr(start, end - start + 1);

    // Clean special FTS characters that might cause syntax errors: " * ( ) : ^ { } [ ] ;
    for (char& c : s) {
        if (c == '"' || c == '*' || c == '(' || c == ')' || c == ':' ||
            c == '^' || c == '{' || c == '}' || c == '[' || c == ']' || c == ';') {
            c = ' ';
        }
    }

    // Collapse multiple spaces
    std::string clean;
    bool last_space = false;
    for (char c : s) {
        if (std::isspace(static_cast<unsigned char>(c))) {
            if (!last_space && !clean.empty()) {
                clean += ' ';
                last_space = true;
            }
        } else {
            clean += c;
            last_space = false;
        }
    }
    while (!clean.empty() && clean.back() == ' ') clean.pop_back();
    if (clean.empty()) return "";

    // Check if the query is a catalog prefix followed immediately or with space by digits
    // (e.g. M31, M 31, NGC7000, NGC 7000, IC434, IC 434, C20, C 20, Arp208, Arp 208)
    static const std::regex cat_regex(R"(^([A-Za-z]+)\s*(\d+.*)$)");
    std::smatch match;
    if (std::regex_match(clean, match, cat_regex)) {
        std::string cat = match[1].str();
        std::string num = match[2].str();
        return "\"" + cat + " " + num + "\"* OR \"" + cat + num + "\"*";
    }

    // Single token query: prefix match
    if (clean.find(' ') == std::string::npos) {
        return clean + "*";
    }

    // Multi-token: search exact phrase OR AND-combination of prefix tokens
    std::string phrase = "\"" + clean + "\"*";
    std::istringstream iss(clean);
    std::string tok;
    std::string prefix_and;
    while (iss >> tok) {
        if (!prefix_and.empty()) prefix_and += " ";
        prefix_and += tok + "*";
    }
    return phrase + " OR (" + prefix_and + ")";
}

} // namespace

SqliteStorage::SqliteStorage(const std::string& catalog_db_path, const std::string& user_db_path) {
    if (catalog_db_path.empty()) {
        last_error_ = "Database path is empty";
        return;
    }

    bool separate_user_db = !user_db_path.empty() && user_db_path != catalog_db_path;
    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX;

    int rc = sqlite3_open_v2(
        catalog_db_path.c_str(),
        &db_,
        flags,
        nullptr
    );
    if (rc != SQLITE_OK) {
        last_error_ = db_ ? sqlite3_errmsg(db_) : ("Failed to open database: " + catalog_db_path);
        if (db_) {
            sqlite3_close(db_);
            db_ = nullptr;
        }
        return;
    }

    // Enable foreign key support
    sqlite3_exec(db_, "PRAGMA foreign_keys = ON;", nullptr, nullptr, nullptr);

    // Verify that the database contains the required dso_objects table
    sqlite3_stmt* check_stmt = nullptr;
    const char* check_sql = "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='dso_objects';";
    int table_count = 0;
    if (sqlite3_prepare_v2(db_, check_sql, -1, &check_stmt, nullptr) == SQLITE_OK) {
        if (sqlite3_step(check_stmt) == SQLITE_ROW) {
            table_count = sqlite3_column_int(check_stmt, 0);
        }
        sqlite3_finalize(check_stmt);
    }
    if (table_count == 0) {
        last_error_ = "Database file is missing 'dso_objects' table";
        sqlite3_close(db_);
        db_ = nullptr;
        return;
    }

    if (separate_user_db) {
        // Attach user database for reading and writing user lists/descriptions
        sqlite3_stmt* attach_stmt = nullptr;
        const char* attach_sql = "ATTACH DATABASE ? AS user_data;";
        if (sqlite3_prepare_v2(db_, attach_sql, -1, &attach_stmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(attach_stmt, 1, user_db_path.c_str(), -1, SQLITE_TRANSIENT);
            if (sqlite3_step(attach_stmt) == SQLITE_DONE) {
                has_user_db_ = true;
            } else {
                last_error_ = sqlite3_errmsg(db_);
            }
            sqlite3_finalize(attach_stmt);
        } else {
            last_error_ = sqlite3_errmsg(db_);
        }
    }

    init_schema();
}

SqliteStorage::~SqliteStorage() {
    if (db_) {
        sqlite3_close(db_);
        db_ = nullptr;
    }
}

SqliteStorage::SqliteStorage(SqliteStorage&& o) noexcept
    : db_(o.db_), has_user_db_(o.has_user_db_), last_error_(std::move(o.last_error_)) {
    o.db_ = nullptr;
    o.has_user_db_ = false;
}

SqliteStorage& SqliteStorage::operator=(SqliteStorage&& o) noexcept {
    if (this != &o) {
        if (db_) sqlite3_close(db_);
        db_ = o.db_;
        has_user_db_ = o.has_user_db_;
        last_error_ = std::move(o.last_error_);
        o.db_ = nullptr;
        o.has_user_db_ = false;
    }
    return *this;
}

bool SqliteStorage::is_open() const {
    return db_ != nullptr;
}

void SqliteStorage::init_schema() {
    if (!db_) return;

    std::string prefix = has_user_db_ ? "user_data." : "";

    std::string schema_sql =
        "CREATE TABLE IF NOT EXISTS " + prefix + "user_lists ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name TEXT NOT NULL,"
        "  description TEXT,"
        "  session_date TEXT,"
        "  created_at INTEGER NOT NULL"
        ");"
        "CREATE TABLE IF NOT EXISTS " + prefix + "user_list_items ("
        "  list_id INTEGER NOT NULL,"
        "  dso_id INTEGER NOT NULL,"
        "  notes TEXT,"
        "  status TEXT DEFAULT 'planned',"
        "  added_at INTEGER NOT NULL,"
        "  PRIMARY KEY (list_id, dso_id)"
        ");"
        "CREATE TABLE IF NOT EXISTS " + prefix + "target_descriptions ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  title TEXT NOT NULL,"
        "  description TEXT,"
        "  extract TEXT NOT NULL,"
        "  thumbnail_url TEXT,"
        "  page_url TEXT,"
        "  source TEXT DEFAULT 'Wikipedia',"
        "  created_at INTEGER"
        ");"
        "CREATE TABLE IF NOT EXISTS " + prefix + "target_description_aliases ("
        "  target_name TEXT PRIMARY KEY,"
        "  description_id INTEGER NOT NULL"
        ");"
        "CREATE INDEX IF NOT EXISTS " + prefix + "idx_tda_name ON target_description_aliases(target_name COLLATE NOCASE);"
        "CREATE INDEX IF NOT EXISTS " + prefix + "idx_td_title ON target_descriptions(title COLLATE NOCASE);";

    char* err_msg = nullptr;
    sqlite3_exec(db_, schema_sql.c_str(), nullptr, nullptr, &err_msg);
    if (err_msg) {
        last_error_ = err_msg;
        sqlite3_free(err_msg);
    }
}

std::vector<catalog::DsoObject> SqliteStorage::query_objects(
    const catalog::DsoFilterOptions& options
) {
    std::vector<catalog::DsoObject> results;
    if (!db_) return results;

    bool has_search = !options.search_query.empty();

    if (has_search) {
        std::ostringstream sql;
        sql << "SELECT d.id, d.name, d.messier, d.caldwell, d.arp, d.herschel, d.ngc_ic, d.catalog, d.catalog_number, "
            << "d.object_type, d.constellation, d.ra_deg, d.dec_deg, d.magnitude, d.b_mag, "
            << "d.major_axis_arcmin, d.minor_axis_arcmin, d.position_angle_deg, d.surface_brightness, d.common_names, d.identifiers "
            << "FROM dso_objects d "
            << "JOIN dso_fts f ON d.id = f.rowid "
            << "WHERE dso_fts MATCH ? "
            << "ORDER BY bm25(dso_fts) "
            << "LIMIT " << options.limit << " OFFSET " << options.offset << ";";

        std::string fts_query = build_fts_query(options.search_query);

        sqlite3_stmt* raw_stmt = nullptr;
        std::string sql_str = sql.str();
        int rc = sqlite3_prepare_v2(db_, sql_str.c_str(), -1, &raw_stmt, nullptr);
        if (rc == SQLITE_OK) {
            UniqueStmt stmt(raw_stmt);
            sqlite3_bind_text(stmt.get(), 1, fts_query.c_str(), -1, SQLITE_TRANSIENT);
            while (sqlite3_step(stmt.get()) == SQLITE_ROW) {
                results.push_back(row_to_dso(stmt.get()));
            }
        }

        // Fallback: If FTS returned 0 candidates, execute LIKE fallback on exact fields
        if (results.empty()) {
            const char* fallback_sql =
                "SELECT d.id, d.name, d.messier, d.caldwell, d.arp, d.herschel, d.ngc_ic, d.catalog, d.catalog_number, "
                "d.object_type, d.constellation, d.ra_deg, d.dec_deg, d.magnitude, d.b_mag, "
                "d.major_axis_arcmin, d.minor_axis_arcmin, d.position_angle_deg, d.surface_brightness, d.common_names, d.identifiers "
                "FROM dso_objects d "
                "WHERE d.name LIKE ? OR d.messier LIKE ? OR d.caldwell LIKE ? OR d.arp LIKE ? "
                "   OR d.herschel LIKE ? OR d.ngc_ic LIKE ? OR d.common_names LIKE ? OR d.identifiers LIKE ? "
                "LIMIT 50;";
            sqlite3_stmt* fb_stmt = nullptr;
            if (sqlite3_prepare_v2(db_, fallback_sql, -1, &fb_stmt, nullptr) == SQLITE_OK) {
                UniqueStmt stmt(fb_stmt);
                std::string like_pattern = "%" + options.search_query + "%";
                for (int i = 1; i <= 8; ++i) {
                    sqlite3_bind_text(stmt.get(), i, like_pattern.c_str(), -1, SQLITE_TRANSIENT);
                }
                while (sqlite3_step(stmt.get()) == SQLITE_ROW) {
                    results.push_back(row_to_dso(stmt.get()));
                }
            }
        }

        return results;
    }

    // Normal browsing (no explicit search query)
    std::ostringstream sql;
    sql << "SELECT d.id, d.name, d.messier, d.caldwell, d.arp, d.herschel, d.ngc_ic, d.catalog, d.catalog_number, "
        << "d.object_type, d.constellation, d.ra_deg, d.dec_deg, d.magnitude, d.b_mag, "
        << "d.major_axis_arcmin, d.minor_axis_arcmin, d.position_angle_deg, d.surface_brightness, d.common_names, d.identifiers "
        << "FROM dso_objects d "
        << "WHERE 1=1 ";

    struct ParamBind {
        enum class Type { Text, Double, Int64 };
        Type type;
        std::string str_val;
        double dbl_val{0.0};
        int64_t int_val{0};
    };
    std::vector<ParamBind> binds;

    // Catalogs filter
    if (!options.catalogs.empty()) {
        sql << "AND (";
        for (size_t i = 0; i < options.catalogs.size(); ++i) {
            if (i > 0) sql << " OR ";
            const auto& cat = options.catalogs[i];
            if (cat == "Messier") {
                sql << "d.messier IS NOT NULL";
            } else if (cat == "Caldwell") {
                sql << "d.caldwell IS NOT NULL";
            } else if (cat == "Arp") {
                sql << "d.arp IS NOT NULL";
            } else if (cat == "Herschel") {
                sql << "d.herschel IS NOT NULL";
            } else {
                sql << "d.catalog = ?";
                binds.push_back({ParamBind::Type::Text, cat, 0.0, 0});
            }
        }
        sql << ") ";
    }

    // Object types filter
    if (!options.object_types.empty()) {
        sql << "AND d.object_type IN (";
        for (size_t i = 0; i < options.object_types.size(); ++i) {
            if (i > 0) sql << ",";
            sql << "?";
            binds.push_back({ParamBind::Type::Text, options.object_types[i], 0.0, 0});
        }
        sql << ") ";
    }

    // Magnitude
    if (options.max_magnitude.has_value()) {
        sql << "AND (d.magnitude IS NOT NULL AND d.magnitude <= ?) ";
        binds.push_back({ParamBind::Type::Double, "", *options.max_magnitude, 0});
    }
    if (options.min_magnitude.has_value()) {
        sql << "AND (d.magnitude IS NOT NULL AND d.magnitude >= ?) ";
        binds.push_back({ParamBind::Type::Double, "", *options.min_magnitude, 0});
    }

    // Size
    if (options.min_size_arcmin.has_value()) {
        sql << "AND (d.major_axis_arcmin IS NOT NULL AND d.major_axis_arcmin >= ?) ";
        binds.push_back({ParamBind::Type::Double, "", *options.min_size_arcmin, 0});
    }
    if (options.max_size_arcmin.has_value()) {
        sql << "AND (d.major_axis_arcmin IS NOT NULL AND d.major_axis_arcmin <= ?) ";
        binds.push_back({ParamBind::Type::Double, "", *options.max_size_arcmin, 0});
    }

    // Constellation
    if (options.constellation.has_value() && !options.constellation->empty()) {
        sql << "AND d.constellation = ? ";
        binds.push_back({ParamBind::Type::Text, *options.constellation, 0.0, 0});
    }

    // Order and Limit
    sql << "ORDER BY (d.messier IS NOT NULL OR d.caldwell IS NOT NULL OR d.arp IS NOT NULL OR d.herschel IS NOT NULL) DESC, (d.magnitude IS NULL), d.magnitude ASC ";
    sql << "LIMIT ? OFFSET ?;";
    binds.push_back({ParamBind::Type::Int64, "", 0.0, static_cast<int64_t>(options.limit)});
    binds.push_back({ParamBind::Type::Int64, "", 0.0, static_cast<int64_t>(options.offset)});

    sqlite3_stmt* raw_stmt = nullptr;
    std::string sql_str = sql.str();
    int rc = sqlite3_prepare_v2(db_, sql_str.c_str(), -1, &raw_stmt, nullptr);
    if (rc != SQLITE_OK) {
        last_error_ = sqlite3_errmsg(db_);
        return results;
    }
    UniqueStmt stmt(raw_stmt);

    for (size_t i = 0; i < binds.size(); ++i) {
        int idx = static_cast<int>(i + 1);
        const auto& b = binds[i];
        if (b.type == ParamBind::Type::Text) {
            sqlite3_bind_text(stmt.get(), idx, b.str_val.c_str(), -1, SQLITE_TRANSIENT);
        } else if (b.type == ParamBind::Type::Double) {
            sqlite3_bind_double(stmt.get(), idx, b.dbl_val);
        } else if (b.type == ParamBind::Type::Int64) {
            sqlite3_bind_int64(stmt.get(), idx, b.int_val);
        }
    }

    while (sqlite3_step(stmt.get()) == SQLITE_ROW) {
        results.push_back(row_to_dso(stmt.get()));
    }

    return results;
}

std::optional<catalog::DsoObject> SqliteStorage::get_object_by_id(std::int64_t id) {
    if (!db_) return std::nullopt;

    const char* sql =
        "SELECT id, name, messier, caldwell, arp, herschel, ngc_ic, catalog, catalog_number, "
        "object_type, constellation, ra_deg, dec_deg, magnitude, b_mag, "
        "major_axis_arcmin, minor_axis_arcmin, position_angle_deg, surface_brightness, common_names, identifiers "
        "FROM dso_objects WHERE id = ?;";

    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &raw_stmt, nullptr) != SQLITE_OK) {
        return std::nullopt;
    }
    UniqueStmt stmt(raw_stmt);
    sqlite3_bind_int64(stmt.get(), 1, id);

    if (sqlite3_step(stmt.get()) == SQLITE_ROW) {
        return row_to_dso(stmt.get());
    }

    return std::nullopt;
}

std::vector<catalog::TargetWithVisibility> SqliteStorage::filter_targets(
    const coordinates::ObserverLocation& obs,
    const catalog::DsoFilterOptions& filter_options,
    const visibility::VisibilityCriteria& visibility_criteria,
    int step_minutes
) {
    services::TargetFilterService service(*this);
    return service.filter_targets(obs, filter_options, visibility_criteria, step_minutes);
}

std::vector<catalog::TargetWithPeriodVisibility> SqliteStorage::filter_targets_period(
    const coordinates::ObserverLocation& obs,
    const catalog::DsoFilterOptions& filter_options,
    const visibility::VisibilityCriteria& visibility_criteria,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes
) {
    services::TargetFilterService service(*this);
    return service.filter_targets_period(obs, filter_options, visibility_criteria, start_jd, end_jd, step_minutes);
}

std::int64_t SqliteStorage::create_list(
    const std::string& name,
    const std::string& description,
    const std::string& session_date
) {
    if (!db_) return -1;

    std::string sql = "INSERT INTO " + std::string(has_user_db_ ? "user_data.user_lists" : "user_lists") +
                      " (name, description, session_date, created_at) VALUES (?, ?, ?, ?);";
    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql.c_str(), -1, &raw_stmt, nullptr) != SQLITE_OK) {
        last_error_ = sqlite3_errmsg(db_);
        return -1;
    }
    UniqueStmt stmt(raw_stmt);

    auto now_epoch = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();

    sqlite3_bind_text(stmt.get(), 1, name.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 2, description.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 3, session_date.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt.get(), 4, now_epoch);

    if (sqlite3_step(stmt.get()) != SQLITE_DONE) {
        last_error_ = sqlite3_errmsg(db_);
        return -1;
    }

    return sqlite3_last_insert_rowid(db_);
}

bool SqliteStorage::delete_list(std::int64_t list_id) {
    if (!db_) return false;

    // Use a transaction to ensure atomic deletion
    sqlite3_exec(db_, "BEGIN IMMEDIATE;", nullptr, nullptr, nullptr);

    std::string items_tbl = has_user_db_ ? "user_data.user_list_items" : "user_list_items";
    std::string lists_tbl = has_user_db_ ? "user_data.user_lists" : "user_lists";

    std::string sql1 = "DELETE FROM " + items_tbl + " WHERE list_id = ?;";
    std::string sql2 = "DELETE FROM " + lists_tbl + " WHERE id = ?;";

    bool ok = true;
    sqlite3_stmt* s1 = nullptr;
    if (sqlite3_prepare_v2(db_, sql1.c_str(), -1, &s1, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(s1, 1, list_id);
        if (sqlite3_step(s1) != SQLITE_DONE) ok = false;
        sqlite3_finalize(s1);
    } else {
        ok = false;
    }

    if (ok) {
        sqlite3_stmt* s2 = nullptr;
        if (sqlite3_prepare_v2(db_, sql2.c_str(), -1, &s2, nullptr) == SQLITE_OK) {
            sqlite3_bind_int64(s2, 1, list_id);
            if (sqlite3_step(s2) != SQLITE_DONE) ok = false;
            sqlite3_finalize(s2);
        } else {
            ok = false;
        }
    }

    if (ok) {
        sqlite3_exec(db_, "COMMIT;", nullptr, nullptr, nullptr);
    } else {
        last_error_ = sqlite3_errmsg(db_);
        sqlite3_exec(db_, "ROLLBACK;", nullptr, nullptr, nullptr);
    }

    return ok;
}

std::vector<ObservingList> SqliteStorage::get_all_lists() {
    std::vector<ObservingList> lists;
    if (!db_) return lists;

    std::string sql = "SELECT id, name, description, session_date, created_at FROM " +
                      std::string(has_user_db_ ? "user_data.user_lists" : "user_lists") +
                      " ORDER BY created_at DESC;";
    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql.c_str(), -1, &raw_stmt, nullptr) != SQLITE_OK) {
        return lists;
    }
    UniqueStmt stmt(raw_stmt);

    while (sqlite3_step(stmt.get()) == SQLITE_ROW) {
        ObservingList l;
        l.id = sqlite3_column_int64(stmt.get(), 0);

        const auto* n = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 1));
        if (n) l.name = n;

        const auto* d = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 2));
        if (d) l.description = d;

        const auto* sd = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 3));
        if (sd) l.session_date = sd;

        l.created_at = sqlite3_column_int64(stmt.get(), 4);
        l.items = get_items_in_list(l.id);
        lists.push_back(std::move(l));
    }

    return lists;
}

bool SqliteStorage::add_target_to_list(
    std::int64_t list_id,
    std::int64_t dso_id,
    const std::string& notes
) {
    if (!db_) return false;

    std::string sql =
        "INSERT OR REPLACE INTO " + std::string(has_user_db_ ? "user_data.user_list_items" : "user_list_items") +
        " (list_id, dso_id, notes, status, added_at) VALUES (?, ?, ?, 'planned', ?);";

    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql.c_str(), -1, &raw_stmt, nullptr) != SQLITE_OK) {
        last_error_ = sqlite3_errmsg(db_);
        return false;
    }
    UniqueStmt stmt(raw_stmt);

    auto now_epoch = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();

    sqlite3_bind_int64(stmt.get(), 1, list_id);
    sqlite3_bind_int64(stmt.get(), 2, dso_id);
    sqlite3_bind_text(stmt.get(), 3, notes.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt.get(), 4, now_epoch);

    return sqlite3_step(stmt.get()) == SQLITE_DONE;
}

bool SqliteStorage::remove_target_from_list(std::int64_t list_id, std::int64_t dso_id) {
    if (!db_) return false;

    std::string sql = "DELETE FROM " + std::string(has_user_db_ ? "user_data.user_list_items" : "user_list_items") +
                      " WHERE list_id = ? AND dso_id = ?;";
    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql.c_str(), -1, &raw_stmt, nullptr) != SQLITE_OK) {
        return false;
    }
    UniqueStmt stmt(raw_stmt);
    sqlite3_bind_int64(stmt.get(), 1, list_id);
    sqlite3_bind_int64(stmt.get(), 2, dso_id);

    return sqlite3_step(stmt.get()) == SQLITE_DONE;
}

std::vector<ObservingListItem> SqliteStorage::get_items_in_list(std::int64_t list_id) {
    std::vector<ObservingListItem> items;
    if (!db_) return items;

    std::string items_tbl = has_user_db_ ? "user_data.user_list_items" : "user_list_items";
    std::string sql =
        "SELECT i.list_id, i.dso_id, i.notes, i.status, i.added_at, "
        "d.id, d.name, d.messier, d.caldwell, d.ngc_ic, d.catalog, d.catalog_number, "
        "d.object_type, d.constellation, d.ra_deg, d.dec_deg, d.magnitude, d.b_mag, "
        "d.major_axis_arcmin, d.minor_axis_arcmin, d.position_angle_deg, d.surface_brightness, d.common_names, d.identifiers "
        "FROM " + items_tbl + " i "
        "JOIN dso_objects d ON i.dso_id = d.id "
        "WHERE i.list_id = ? "
        "ORDER BY i.added_at ASC;";

    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql.c_str(), -1, &raw_stmt, nullptr) != SQLITE_OK) {
        return items;
    }
    UniqueStmt stmt(raw_stmt);
    sqlite3_bind_int64(stmt.get(), 1, list_id);

    while (sqlite3_step(stmt.get()) == SQLITE_ROW) {
        ObservingListItem item;
        item.list_id = sqlite3_column_int64(stmt.get(), 0);
        item.dso_id = sqlite3_column_int64(stmt.get(), 1);

        const auto* n = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 2));
        if (n) item.notes = n;

        const auto* s = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 3));
        if (s) item.status = s;

        item.added_at = sqlite3_column_int64(stmt.get(), 4);

        auto dso = get_object_by_id(item.dso_id);
        if (dso) item.dso = *dso;

        items.push_back(std::move(item));
    }

    return items;
}

bool SqliteStorage::clear_all_lists() {
    if (!db_) return false;
    std::string items_tbl = has_user_db_ ? "user_data.user_list_items" : "user_list_items";
    std::string lists_tbl = has_user_db_ ? "user_data.user_lists" : "user_lists";
    std::string sql = "BEGIN IMMEDIATE; DELETE FROM " + items_tbl + "; DELETE FROM " + lists_tbl + "; COMMIT;";
    char* err_msg = nullptr;
    int rc = sqlite3_exec(db_, sql.c_str(), nullptr, nullptr, &err_msg);
    if (err_msg) {
        last_error_ = err_msg;
        sqlite3_free(err_msg);
        sqlite3_exec(db_, "ROLLBACK;", nullptr, nullptr, nullptr);
        return false;
    }
    return rc == SQLITE_OK;
}

std::optional<TargetDescriptionRecord> SqliteStorage::get_target_description(const std::string& target_name) {
    if (!db_ || target_name.empty()) return std::nullopt;

    std::string desc_tbl = has_user_db_ ? "user_data.target_descriptions" : "target_descriptions";
    std::string alias_tbl = has_user_db_ ? "user_data.target_description_aliases" : "target_description_aliases";

    std::string sql =
        "SELECT d.title, d.description, d.extract, d.thumbnail_url, d.page_url, d.source "
        "FROM " + desc_tbl + " d "
        "LEFT JOIN " + alias_tbl + " a ON d.id = a.description_id "
        "WHERE a.target_name = ? COLLATE NOCASE OR d.title = ? COLLATE NOCASE "
        "LIMIT 1;";

    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql.c_str(), -1, &raw_stmt, nullptr) != SQLITE_OK) {
        last_error_ = sqlite3_errmsg(db_);
        return std::nullopt;
    }
    UniqueStmt stmt(raw_stmt);
    sqlite3_bind_text(stmt.get(), 1, target_name.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 2, target_name.c_str(), -1, SQLITE_TRANSIENT);

    if (sqlite3_step(stmt.get()) == SQLITE_ROW) {
        TargetDescriptionRecord rec;
        const auto* ti = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 0));
        if (ti) rec.title = ti;
        const auto* de = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 1));
        if (de) rec.description = de;
        const auto* ex = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 2));
        if (ex) rec.extract = ex;
        const auto* th = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 3));
        if (th) rec.thumbnail_url = th;
        const auto* pu = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 4));
        if (pu) rec.page_url = pu;
        const auto* so = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 5));
        if (so) rec.source = so;
        return rec;
    }
    return std::nullopt;
}

bool SqliteStorage::save_target_description(
    const std::string& title,
    const std::string& description,
    const std::string& extract,
    const std::string& thumbnail_url,
    const std::string& page_url,
    const std::string& source,
    const std::vector<std::string>& aliases
) {
    if (!db_ || title.empty() || extract.empty()) return false;

    std::string desc_tbl = has_user_db_ ? "user_data.target_descriptions" : "target_descriptions";
    std::string alias_tbl = has_user_db_ ? "user_data.target_description_aliases" : "target_description_aliases";

    // Check if title already exists in target_descriptions
    int64_t desc_id = 0;
    std::string find_sql = "SELECT id FROM " + desc_tbl + " WHERE title = ? COLLATE NOCASE LIMIT 1;";
    sqlite3_stmt* f_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, find_sql.c_str(), -1, &f_stmt, nullptr) == SQLITE_OK) {
        UniqueStmt stmt(f_stmt);
        sqlite3_bind_text(stmt.get(), 1, title.c_str(), -1, SQLITE_TRANSIENT);
        if (sqlite3_step(stmt.get()) == SQLITE_ROW) {
            desc_id = sqlite3_column_int64(stmt.get(), 0);
        }
    }

    if (desc_id > 0) {
        std::string upd_sql =
            "UPDATE " + desc_tbl + " SET description = ?, extract = ?, thumbnail_url = ?, page_url = ?, source = ? WHERE id = ?;";
        sqlite3_stmt* u_stmt = nullptr;
        if (sqlite3_prepare_v2(db_, upd_sql.c_str(), -1, &u_stmt, nullptr) == SQLITE_OK) {
            UniqueStmt stmt(u_stmt);
            sqlite3_bind_text(stmt.get(), 1, description.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt.get(), 2, extract.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt.get(), 3, thumbnail_url.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt.get(), 4, page_url.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt.get(), 5, source.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_int64(stmt.get(), 6, desc_id);
            sqlite3_step(stmt.get());
        }
    } else {
        std::string ins_sql =
            "INSERT INTO " + desc_tbl + " (title, description, extract, thumbnail_url, page_url, source, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?);";
        sqlite3_stmt* i_stmt = nullptr;
        if (sqlite3_prepare_v2(db_, ins_sql.c_str(), -1, &i_stmt, nullptr) == SQLITE_OK) {
            UniqueStmt stmt(i_stmt);
            sqlite3_bind_text(stmt.get(), 1, title.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt.get(), 2, description.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt.get(), 3, extract.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt.get(), 4, thumbnail_url.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt.get(), 5, page_url.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt.get(), 6, source.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_int64(stmt.get(), 7, static_cast<int64_t>(std::time(nullptr)));
            if (sqlite3_step(stmt.get()) == SQLITE_DONE) {
                desc_id = sqlite3_last_insert_rowid(db_);
            }
        }
    }

    if (desc_id <= 0) return false;

    // Link aliases
    std::string alias_sql = "INSERT OR REPLACE INTO " + alias_tbl + " (target_name, description_id) VALUES (?, ?);";
    for (const auto& alias : aliases) {
        if (alias.empty()) continue;
        sqlite3_stmt* a_stmt = nullptr;
        if (sqlite3_prepare_v2(db_, alias_sql.c_str(), -1, &a_stmt, nullptr) == SQLITE_OK) {
            UniqueStmt stmt(a_stmt);
            sqlite3_bind_text(stmt.get(), 1, alias.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_int64(stmt.get(), 2, desc_id);
            sqlite3_step(stmt.get());
        }
    }

    // Also link the title itself as an alias
    sqlite3_stmt* t_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, alias_sql.c_str(), -1, &t_stmt, nullptr) == SQLITE_OK) {
        UniqueStmt stmt(t_stmt);
        sqlite3_bind_text(stmt.get(), 1, title.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt.get(), 2, desc_id);
        sqlite3_step(stmt.get());
    }

    return true;
}

} // namespace astro::storage
