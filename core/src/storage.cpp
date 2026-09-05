#include "astro/storage.hpp"
#include "sqlite3.h"

#include <algorithm>
#include <chrono>
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

    const auto* ngc_ic = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4));
    if (ngc_ic) obj.ngc_ic = ngc_ic;

    const auto* cat = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));
    if (cat) obj.catalog = cat;

    const auto* cat_num = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 6));
    if (cat_num) obj.catalog_number = cat_num;

    const auto* obj_type = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 7));
    if (obj_type) obj.object_type = obj_type;

    const auto* constel = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 8));
    if (constel) obj.constellation = constel;

    double ra_deg = sqlite3_column_double(stmt, 9);
    double dec_deg = sqlite3_column_double(stmt, 10);
    obj.coordinates.ra = units::degrees_to_hours(units::Degrees{ra_deg});
    obj.coordinates.dec = units::Degrees{dec_deg};

    if (sqlite3_column_type(stmt, 11) != SQLITE_NULL) {
        obj.magnitude = sqlite3_column_double(stmt, 11);
    }
    if (sqlite3_column_type(stmt, 12) != SQLITE_NULL) {
        obj.b_mag = sqlite3_column_double(stmt, 12);
    }
    if (sqlite3_column_type(stmt, 13) != SQLITE_NULL) {
        obj.major_axis_arcmin = sqlite3_column_double(stmt, 13);
    }
    if (sqlite3_column_type(stmt, 14) != SQLITE_NULL) {
        obj.minor_axis_arcmin = sqlite3_column_double(stmt, 14);
    }
    if (sqlite3_column_type(stmt, 15) != SQLITE_NULL) {
        obj.surface_brightness = sqlite3_column_double(stmt, 15);
    }

    const auto* common = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 16));
    if (common) obj.common_names = common;

    const auto* ident = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 17));
    if (ident) obj.identifiers = ident;

    return obj;
}

} // namespace

SqliteStorage::SqliteStorage(const std::string& db_path) {
    int rc = sqlite3_open_v2(
        db_path.c_str(),
        &db_,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
        nullptr
    );
    if (rc != SQLITE_OK) {
        last_error_ = sqlite3_errmsg(db_);
        if (db_) {
            sqlite3_close(db_);
            db_ = nullptr;
        }
    } else {
        init_schema();
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

    std::ostringstream sql;
    bool has_search = !options.search_query.empty();

    if (has_search) {
        sql << "SELECT d.id, d.name, d.messier, d.caldwell, d.ngc_ic, d.catalog, d.catalog_number, "
            << "d.object_type, d.constellation, d.ra_deg, d.dec_deg, d.magnitude, d.b_mag, "
            << "d.major_axis_arcmin, d.minor_axis_arcmin, d.surface_brightness, d.common_names, d.identifiers "
            << "FROM dso_objects d "
            << "JOIN dso_fts f ON d.id = f.rowid "
            << "WHERE dso_fts MATCH ? ";
    } else {
        sql << "SELECT d.id, d.name, d.messier, d.caldwell, d.ngc_ic, d.catalog, d.catalog_number, "
            << "d.object_type, d.constellation, d.ra_deg, d.dec_deg, d.magnitude, d.b_mag, "
            << "d.major_axis_arcmin, d.minor_axis_arcmin, d.surface_brightness, d.common_names, d.identifiers "
            << "FROM dso_objects d "
            << "WHERE 1=1 ";
    }

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
    if (has_search) {
        sql << "ORDER BY bm25(dso_fts) ";
    } else {
        sql << "ORDER BY (d.messier IS NOT NULL) DESC, (d.magnitude IS NULL), d.magnitude ASC ";
    }

    sql << "LIMIT " << options.limit << " OFFSET " << options.offset << ";";

    sqlite3_stmt* raw_stmt = nullptr;
    std::string sql_str = sql.str();
    int rc = sqlite3_prepare_v2(db_, sql_str.c_str(), -1, &raw_stmt, nullptr);
    if (rc != SQLITE_OK) {
        last_error_ = sqlite3_errmsg(db_);
        return results;
    }
    UniqueStmt stmt(raw_stmt);

    if (has_search) {
        // Append wildcard for prefix search if not present
        std::string query = options.search_query;
        if (!query.empty() && query.back() != '*') {
            query += "*";
        }
        sqlite3_bind_text(stmt.get(), 1, query.c_str(), -1, SQLITE_TRANSIENT);
    }

    while (sqlite3_step(stmt.get()) == SQLITE_ROW) {
        results.push_back(row_to_dso(stmt.get()));
    }

    return results;
}

std::optional<catalog::DsoObject> SqliteStorage::get_object_by_id(std::int64_t id) {
    if (!db_) return std::nullopt;

    const char* sql =
        "SELECT id, name, messier, caldwell, ngc_ic, catalog, catalog_number, "
        "object_type, constellation, ra_deg, dec_deg, magnitude, b_mag, "
        "major_axis_arcmin, minor_axis_arcmin, surface_brightness, common_names, identifiers "
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

    // Fetch matching objects from catalog (up to e.g. 2000 candidates)
    catalog::DsoFilterOptions candidate_opts = filter_options;
    if (candidate_opts.limit <= 0 || candidate_opts.limit > 2000) {
        candidate_opts.limit = 2000;
    }

    std::vector<catalog::DsoObject> candidates = query_objects(candidate_opts);

    for (const auto& dso : candidates) {
        auto vis = visibility::evaluate_visibility(
            dso.coordinates,
            obs,
            visibility_criteria,
            step_minutes,
            /*include_samples=*/false
        );

        if (vis.meets_criteria) {
            results.push_back({dso, vis});
        }
    }

    // Sort by peak altitude descending
    std::sort(results.begin(), results.end(), [](const auto& a, const auto& b) {
        return a.visibility.peak_altitude.value > b.visibility.peak_altitude.value;
    });

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
        "d.major_axis_arcmin, d.minor_axis_arcmin, d.surface_brightness, d.common_names, d.identifiers "
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

} // namespace astro::storage
