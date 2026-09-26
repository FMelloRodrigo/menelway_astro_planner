#include "astro/storage.hpp"
#include "sqlite3.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <regex>
#include <sstream>

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
    std::string cleaned;
    for (char c : s) {
        if (c == '"' || c == '*' || c == '(' || c == ')' || c == ':' || 
            c == '^' || c == '{' || c == '}' || c == '[' || c == ']' || c == ';') {
            cleaned += ' ';
        } else {
            cleaned += c;
        }
    }

    // Collapse multiple spaces
    std::string collapsed;
    bool in_space = false;
    for (char c : cleaned) {
        if (std::isspace(static_cast<unsigned char>(c))) {
            if (!in_space) {
                collapsed += ' ';
                in_space = true;
            }
        } else {
            collapsed += c;
            in_space = false;
        }
    }

    // Trim collapsed
    start = collapsed.find_first_not_of(" ");
    if (start == std::string::npos) return "";
    end = collapsed.find_last_not_of(" ");
    collapsed = collapsed.substr(start, end - start + 1);

    // Regex check for standard astronomical catalog patterns:
    // e.g. M42 / M 42, NGC1976 / NGC 1976, IC434 / IC 434, C14 / C 14, Arp220 / Arp 220, H400 / H 400
    static const std::regex m_re(R"(^[Mm]\s*(\d+)$)");
    static const std::regex ngc_re(R"(^[Nn][Gg][Cc]\s*(\d+)$)");
    static const std::regex ic_re(R"(^[Ii][Cc]\s*(\d+)$)");
    static const std::regex c_re(R"(^[Cc]\s*(\d+)$)");
    static const std::regex arp_re(R"(^[Aa][Rr][Pp]\s*(\d+)$)");
    static const std::regex h_re(R"(^[Hh]\s*(\d+.*)$)");
    static const std::regex b_re(R"(^[Bb]\s*(\d+)$)");

    std::smatch m;
    if (std::regex_match(collapsed, m, m_re)) {
        std::string num = m[1].str();
        return "\"M " + num + "\"* OR M" + num + "*";
    }
    if (std::regex_match(collapsed, m, ngc_re)) {
        std::string num = m[1].str();
        return "\"NGC " + num + "\"* OR NGC" + num + "*";
    }
    if (std::regex_match(collapsed, m, ic_re)) {
        std::string num = m[1].str();
        return "\"IC " + num + "\"* OR IC" + num + "*";
    }
    if (std::regex_match(collapsed, m, c_re)) {
        std::string num = m[1].str();
        return "\"C " + num + "\"* OR C" + num + "*";
    }
    if (std::regex_match(collapsed, m, arp_re)) {
        std::string num = m[1].str();
        return "\"Arp " + num + "\"* OR Arp" + num + "*";
    }
    if (std::regex_match(collapsed, m, h_re)) {
        std::string num = m[1].str();
        return "\"H " + num + "\"* OR H" + num + "*";
    }
    if (std::regex_match(collapsed, m, b_re)) {
        std::string num = m[1].str();
        return "\"B " + num + "\"* OR B" + num + "*";
    }

    // Single token query: prefix match
    if (collapsed.find(' ') == std::string::npos) {
        return collapsed + "*";
    }

    // Multi-token: search exact phrase OR AND-combination of prefix tokens
    std::string phrase = "\"" + collapsed + "\"*";
    std::istringstream iss(collapsed);
    std::string tok;
    std::string prefix_and;
    while (iss >> tok) {
        if (!prefix_and.empty()) prefix_and += " ";
        prefix_and += tok + "*";
    }
    return phrase + " OR (" + prefix_and + ")";
}

} // namespace

SqliteStorage::SqliteStorage(const std::string& db_path) {
    if (db_path.empty()) {
        last_error_ = "Database path is empty";
        return;
    }
    int rc = sqlite3_open_v2(
        db_path.c_str(),
        &db_,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
        nullptr
    );
    if (rc != SQLITE_OK) {
        last_error_ = db_ ? sqlite3_errmsg(db_) : ("Failed to open database: " + db_path);
        if (db_) {
            sqlite3_close(db_);
            db_ = nullptr;
        }
    } else {
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
        } else {
            init_schema();
        }
    }
}

SqliteStorage::~SqliteStorage() {
    if (db_) {
        sqlite3_close(db_);
        db_ = nullptr;
    }
}

SqliteStorage::SqliteStorage(SqliteStorage&& o) noexcept
    : db_(o.db_), last_error_(std::move(o.last_error_)) {
    o.db_ = nullptr;
}

SqliteStorage& SqliteStorage::operator=(SqliteStorage&& o) noexcept {
    if (this != &o) {
        if (db_) sqlite3_close(db_);
        db_ = o.db_;
        last_error_ = std::move(o.last_error_);
        o.db_ = nullptr;
    }
    return *this;
}

bool SqliteStorage::is_open() const {
    return db_ != nullptr;
}

void SqliteStorage::init_schema() {
    if (!db_) return;

    // Ensure observing lists tables exist
    const char* schema_sql =
        "CREATE TABLE IF NOT EXISTS user_lists ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name TEXT NOT NULL,"
        "  description TEXT,"
        "  session_date TEXT,"
        "  created_at INTEGER NOT NULL"
        ");"
        "CREATE TABLE IF NOT EXISTS user_list_items ("
        "  list_id INTEGER NOT NULL,"
        "  dso_id INTEGER NOT NULL,"
        "  notes TEXT,"
        "  status TEXT DEFAULT 'planned',"
        "  added_at INTEGER NOT NULL,"
        "  PRIMARY KEY (list_id, dso_id),"
        "  FOREIGN KEY (list_id) REFERENCES user_lists(id) ON DELETE CASCADE,"
        "  FOREIGN KEY (dso_id) REFERENCES dso_objects(id)"
        ");";

    char* err_msg = nullptr;
    sqlite3_exec(db_, schema_sql, nullptr, nullptr, &err_msg);
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
                sql << "d.catalog = '" << cat << "'";
            }
        }
        sql << ") ";
    }

    // Object types filter
    if (!options.object_types.empty()) {
        sql << "AND d.object_type IN (";
        for (size_t i = 0; i < options.object_types.size(); ++i) {
            if (i > 0) sql << ",";
            sql << "'" << options.object_types[i] << "'";
        }
        sql << ") ";
    }

    // Magnitude
    if (options.max_magnitude.has_value()) {
        sql << "AND (d.magnitude IS NOT NULL AND d.magnitude <= " << *options.max_magnitude << ") ";
    }
    if (options.min_magnitude.has_value()) {
        sql << "AND (d.magnitude IS NOT NULL AND d.magnitude >= " << *options.min_magnitude << ") ";
    }

    // Size
    if (options.min_size_arcmin.has_value()) {
        sql << "AND (d.major_axis_arcmin IS NOT NULL AND d.major_axis_arcmin >= " << *options.min_size_arcmin << ") ";
    }
    if (options.max_size_arcmin.has_value()) {
        sql << "AND (d.major_axis_arcmin IS NOT NULL AND d.major_axis_arcmin <= " << *options.max_size_arcmin << ") ";
    }

    // Constellation
    if (options.constellation.has_value() && !options.constellation->empty()) {
        sql << "AND d.constellation = '" << *options.constellation << "' ";
    }

    // Order and Limit
    sql << "ORDER BY (d.messier IS NOT NULL OR d.caldwell IS NOT NULL OR d.arp IS NOT NULL OR d.herschel IS NOT NULL) DESC, (d.magnitude IS NULL), d.magnitude ASC ";
    sql << "LIMIT " << options.limit << " OFFSET " << options.offset << ";";

    sqlite3_stmt* raw_stmt = nullptr;
    std::string sql_str = sql.str();
    int rc = sqlite3_prepare_v2(db_, sql_str.c_str(), -1, &raw_stmt, nullptr);
    if (rc != SQLITE_OK) {
        last_error_ = sqlite3_errmsg(db_);
        return results;
    }
    UniqueStmt stmt(raw_stmt);

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
    std::vector<catalog::TargetWithVisibility> results;
    if (!db_) return results;

    // Fetch matching objects from catalog (evaluate comprehensive candidate pool)
    catalog::DsoFilterOptions candidate_opts = filter_options;
    candidate_opts.limit = 15000;
    candidate_opts.offset = 0;

    std::vector<catalog::DsoObject> candidates = query_objects(candidate_opts);
    bool has_search_query = !filter_options.search_query.empty();

    for (const auto& dso : candidates) {
        auto vis = visibility::evaluate_visibility(
            dso.coordinates,
            obs,
            visibility_criteria,
            step_minutes,
            /*include_samples=*/false
        );

        // When actively searching by name/query, keep targets even if they do not meet
        // tonight's criteria so the user can inspect their yearly observing window.
        if (vis.meets_criteria || has_search_query) {
            results.push_back({dso, vis});
        }
    }

    // Sort: objects meeting criteria tonight first, then by brightness (magnitude ASC, nulls last), then peak altitude descending
    std::sort(results.begin(), results.end(), [](const auto& a, const auto& b) {
        if (a.visibility.meets_criteria != b.visibility.meets_criteria) {
            return a.visibility.meets_criteria > b.visibility.meets_criteria;
        }
        bool a_has_mag = a.dso.magnitude.has_value();
        bool b_has_mag = b.dso.magnitude.has_value();
        if (a_has_mag != b_has_mag) {
            return a_has_mag > b_has_mag;
        }
        if (a_has_mag && b_has_mag) {
            double diff = *a.dso.magnitude - *b.dso.magnitude;
            if (std::abs(diff) > 1e-4) {
                return diff < 0.0;
            }
        }
        return a.visibility.peak_altitude.value > b.visibility.peak_altitude.value;
    });

    if (filter_options.limit > 0 && results.size() > static_cast<size_t>(filter_options.limit)) {
        results.resize(filter_options.limit);
    }

    return results;
}

std::vector<catalog::TargetWithPeriodVisibility> SqliteStorage::filter_targets_period(
    const coordinates::ObserverLocation& obs,
    const catalog::DsoFilterOptions& filter_options,
    const visibility::VisibilityCriteria& visibility_criteria,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes
) {
    std::vector<catalog::TargetWithPeriodVisibility> results;
    if (!db_) return results;

    // Fetch matching objects from catalog (evaluate comprehensive candidate pool)
    catalog::DsoFilterOptions candidate_opts = filter_options;
    candidate_opts.limit = 15000;
    candidate_opts.offset = 0;

    std::vector<catalog::DsoObject> candidates = query_objects(candidate_opts);
    bool has_search_query = !filter_options.search_query.empty();

    for (const auto& dso : candidates) {
        auto vis = visibility::evaluate_period_visibility(
            dso.coordinates,
            obs,
            visibility_criteria,
            start_jd,
            end_jd,
            step_minutes
        );

        if (vis.is_observable || has_search_query) {
            results.push_back({dso, vis});
        }
    }

    // Sort: objects meeting criteria first, then by total observable days descending, then peak altitude descending
    std::sort(results.begin(), results.end(), [](const auto& a, const auto& b) {
        if (a.visibility.is_observable != b.visibility.is_observable) {
            return a.visibility.is_observable > b.visibility.is_observable;
        }
        if (a.visibility.total_observable_days != b.visibility.total_observable_days) {
            return a.visibility.total_observable_days > b.visibility.total_observable_days;
        }
        return a.visibility.peak_altitude_deg > b.visibility.peak_altitude_deg;
    });

    if (filter_options.limit > 0 && results.size() > static_cast<size_t>(filter_options.limit)) {
        results.resize(filter_options.limit);
    }

    return results;
}

std::int64_t SqliteStorage::create_list(
    const std::string& name,
    const std::string& description,
    const std::string& session_date
) {
    if (!db_) return -1;

    const char* sql = "INSERT INTO user_lists (name, description, session_date, created_at) VALUES (?, ?, ?, ?);";
    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &raw_stmt, nullptr) != SQLITE_OK) {
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

    // Delete items first then list
    const char* sql1 = "DELETE FROM user_list_items WHERE list_id = ?;";
    const char* sql2 = "DELETE FROM user_lists WHERE id = ?;";

    sqlite3_stmt* s1 = nullptr;
    if (sqlite3_prepare_v2(db_, sql1, -1, &s1, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(s1, 1, list_id);
        sqlite3_step(s1);
        sqlite3_finalize(s1);
    }

    sqlite3_stmt* s2 = nullptr;
    if (sqlite3_prepare_v2(db_, sql2, -1, &s2, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(s2, 1, list_id);
        sqlite3_step(s2);
        sqlite3_finalize(s2);
        return true;
    }

    return false;
}

std::vector<ObservingList> SqliteStorage::get_all_lists() {
    std::vector<ObservingList> lists;
    if (!db_) return lists;

    const char* sql = "SELECT id, name, description, session_date, created_at FROM user_lists ORDER BY created_at DESC;";
    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &raw_stmt, nullptr) != SQLITE_OK) {
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

    const char* sql =
        "INSERT OR REPLACE INTO user_list_items (list_id, dso_id, notes, status, added_at) "
        "VALUES (?, ?, ?, 'planned', ?);";

    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &raw_stmt, nullptr) != SQLITE_OK) {
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

    const char* sql = "DELETE FROM user_list_items WHERE list_id = ? AND dso_id = ?;";
    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &raw_stmt, nullptr) != SQLITE_OK) {
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

    const char* sql =
        "SELECT i.list_id, i.dso_id, i.notes, i.status, i.added_at, "
        "d.id, d.name, d.messier, d.caldwell, d.ngc_ic, d.catalog, d.catalog_number, "
        "d.object_type, d.constellation, d.ra_deg, d.dec_deg, d.magnitude, d.b_mag, "
        "d.major_axis_arcmin, d.minor_axis_arcmin, d.position_angle_deg, d.surface_brightness, d.common_names, d.identifiers "
        "FROM user_list_items i "
        "JOIN dso_objects d ON i.dso_id = d.id "
        "WHERE i.list_id = ? "
        "ORDER BY i.added_at ASC;";

    sqlite3_stmt* raw_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &raw_stmt, nullptr) != SQLITE_OK) {
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

        // Map DSO from column 5 onwards
        // Need to shift stmt column pointer or wrap
        // We can fetch by row_to_dso with offset, or query dso directly:
        auto dso = get_object_by_id(item.dso_id);
        if (dso) item.dso = *dso;

        items.push_back(std::move(item));
    }

    return items;
}

bool SqliteStorage::clear_all_lists() {
    if (!db_) return false;
    const char* sql = "DELETE FROM user_list_items; DELETE FROM user_lists;";
    char* err_msg = nullptr;
    int rc = sqlite3_exec(db_, sql, nullptr, nullptr, &err_msg);
    if (err_msg) {
        last_error_ = err_msg;
        sqlite3_free(err_msg);
        return false;
    }
    return rc == SQLITE_OK;
}

} // namespace astro::storage
