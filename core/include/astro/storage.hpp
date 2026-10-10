#pragma once

#include "astro/catalog.hpp"
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

struct TargetDescriptionRecord {
    std::string title;
    std::string description;
    std::string extract;
    std::string thumbnail_url;
    std::string page_url;
    std::string source{"Wikipedia"};
};

class ICatalogRepository {
public:
    virtual ~ICatalogRepository() = default;

    virtual std::vector<catalog::DsoObject> query_objects(
        const catalog::DsoFilterOptions& options
    ) = 0;

    virtual std::optional<catalog::DsoObject> get_object_by_id(std::int64_t id) = 0;
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

class ITargetDescriptionRepository {
public:
    virtual ~ITargetDescriptionRepository() = default;

    virtual std::optional<TargetDescriptionRecord> get_target_description(const std::string& target_name) = 0;
    virtual bool save_target_description(
        const std::string& title,
        const std::string& description,
        const std::string& extract,
        const std::string& thumbnail_url,
        const std::string& page_url,
        const std::string& source,
        const std::vector<std::string>& aliases
    ) = 0;
};

/// Unified abstract interface for database repositories adhering to SOLID principles.
class IStorage : public ICatalogRepository,
                 public IObservingListRepository,
                 public ITargetDescriptionRepository {
public:
    virtual ~IStorage() = default;

    virtual bool is_open() const = 0;
    virtual const std::string& last_error() const = 0;
};

class SqliteStorage : public IStorage {
public:
    explicit SqliteStorage(const std::string& catalog_db_path, const std::string& user_db_path = "");
    ~SqliteStorage() override;

    SqliteStorage(const SqliteStorage&) = delete;
    SqliteStorage& operator=(const SqliteStorage&) = delete;
    SqliteStorage(SqliteStorage&&) noexcept;
    SqliteStorage& operator=(SqliteStorage&&) noexcept;

    bool is_open() const override;
    const std::string& last_error() const override { return last_error_; }
    bool has_separate_user_db() const { return has_user_db_; }

    // ICatalogRepository implementation
    std::vector<catalog::DsoObject> query_objects(
        const catalog::DsoFilterOptions& options
    ) override;

    std::optional<catalog::DsoObject> get_object_by_id(std::int64_t id) override;

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

    // ITargetDescriptionRepository implementation
    std::optional<TargetDescriptionRecord> get_target_description(const std::string& target_name) override;
    bool save_target_description(
        const std::string& title,
        const std::string& description,
        const std::string& extract,
        const std::string& thumbnail_url,
        const std::string& page_url,
        const std::string& source,
        const std::vector<std::string>& aliases
    ) override;

private:
    sqlite3* db_{nullptr};
    bool has_user_db_{false};
    std::string last_error_;

    void init_schema();
};

} // namespace astro::storage
