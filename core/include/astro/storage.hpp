#pragma once

#include "astro/catalog.hpp"
#include "astro/coordinates.hpp"
#include "astro/visibility.hpp"
#include <memory>
#include <optional>
#include <string>
#include <vector>

struct sqlite3;

namespace astro::storage {

struct ObservingListItem {
    std::int64_t list_id{0};
    std::int64_t dso_id{0};
    catalog::DsoObject dso;
    std::string notes;
    std::string status;
    std::int64_t added_at{0};
};

struct ObservingList {
    std::int64_t id{0};
    std::string name;
    std::string description;
    std::string session_date;
    std::int64_t created_at{0};
    std::vector<ObservingListItem> items;
};

class ICatalogRepository {
public:
    virtual ~ICatalogRepository() = default;

    virtual std::vector<catalog::DsoObject> query_objects(
        const catalog::DsoFilterOptions& options
    ) = 0;

    virtual std::optional<catalog::DsoObject> get_object_by_id(std::int64_t id) = 0;

    virtual std::vector<catalog::TargetWithVisibility> filter_targets(
        const coordinates::ObserverLocation& obs,
        const catalog::DsoFilterOptions& filter_options,
        const visibility::VisibilityCriteria& visibility_criteria,
        int step_minutes = 10
    ) = 0;
};

class IObservingListRepository {
public:
    virtual ~IObservingListRepository() = default;

    virtual std::int64_t create_list(
        const std::string& name,
        const std::string& description,
        const std::string& session_date
    ) = 0;

    virtual bool delete_list(std::int64_t list_id) = 0;

    virtual std::vector<ObservingList> get_all_lists() = 0;

    virtual bool add_target_to_list(
        std::int64_t list_id,
        std::int64_t dso_id,
        const std::string& notes = ""
    ) = 0;

    virtual bool remove_target_from_list(
        std::int64_t list_id,
        std::int64_t dso_id
    ) = 0;

    virtual std::vector<ObservingListItem> get_items_in_list(std::int64_t list_id) = 0;

    virtual bool clear_all_lists() = 0;
};

class SqliteStorage : public ICatalogRepository, public IObservingListRepository {
public:
    explicit SqliteStorage(const std::string& db_path);
    ~SqliteStorage() override;

    SqliteStorage(const SqliteStorage&) = delete;
    SqliteStorage& operator=(const SqliteStorage&) = delete;
    SqliteStorage(SqliteStorage&&) noexcept;
    SqliteStorage& operator=(SqliteStorage&&) noexcept;

    bool is_open() const;
    const std::string& last_error() const { return last_error_; }

    // ICatalogRepository implementation
    std::vector<catalog::DsoObject> query_objects(
        const catalog::DsoFilterOptions& options
    ) override;

    std::optional<catalog::DsoObject> get_object_by_id(std::int64_t id) override;

    std::vector<catalog::TargetWithVisibility> filter_targets(
        const coordinates::ObserverLocation& obs,
        const catalog::DsoFilterOptions& filter_options,
        const visibility::VisibilityCriteria& visibility_criteria,
        int step_minutes = 10
    ) override;

    // IObservingListRepository implementation
    std::int64_t create_list(
        const std::string& name,
        const std::string& description,
        const std::string& session_date
    ) override;

    bool delete_list(std::int64_t list_id) override;

    std::vector<ObservingList> get_all_lists() override;

    bool add_target_to_list(
        std::int64_t list_id,
        std::int64_t dso_id,
        const std::string& notes = ""
    ) override;

    bool remove_target_from_list(
        std::int64_t list_id,
        std::int64_t dso_id
    ) override;

    std::vector<ObservingListItem> get_items_in_list(std::int64_t list_id) override;
    bool clear_all_lists() override;

private:
    sqlite3* db_{nullptr};
    std::string last_error_;

    void init_schema();
};

} // namespace astro::storage
