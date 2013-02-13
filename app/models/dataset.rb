class Dataset < ActiveRecord::Base
  include Stale
  include SoftDelete
  include TaggableBehavior

  belongs_to :schema, :counter_cache => :active_tables_and_views_count

  after_update :update_active_tables_and_views_counter_cache_on_schema
  after_create :skip_active_table_and_views_counter_cache_for_chorus_views
  after_destroy :skip_active_table_and_views_counter_cache_for_chorus_views

  validates_presence_of :schema
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:schema_id,  :type, :deleted_at]

  has_many :activities, :as => :entity
  has_many :events, :through => :activities
  has_many :notes, :through => :activities, :source => :event, :class_name => "Events::Note"
  has_many :comments, :through => :events
  has_many :associated_datasets, :dependent => :destroy
  has_many :bound_workspaces, :through => :associated_datasets, :source => :workspace

  searchable_model :if => :should_reindex? do
    text :name, :stored => true, :boost => SOLR_PRIMARY_FIELD_BOOST
    text :database_name, :stored => true, :boost => SOLR_SECONDARY_FIELD_BOOST
    text :table_description, :stored => true, :boost => SOLR_SECONDARY_FIELD_BOOST
    text :schema_name, :stored => true, :boost => SOLR_SECONDARY_FIELD_BOOST
    text :column_name, :stored => true, :boost => SOLR_SECONDARY_FIELD_BOOST
    text :column_description, :stored => true, :boost => SOLR_SECONDARY_FIELD_BOOST
    text :query, :stored => true, :boost => SOLR_SECONDARY_FIELD_BOOST
  end

  has_shared_search_fields [
                               {:type => :integer, :name => :instance_account_ids, :options => {:multiple => true}},
                               {:type => :integer, :name => :found_in_workspace_id, :options => {:multiple => true}}
                           ]
  attr_accessor :highlighted_attributes, :search_result_notes, :skip_search_index
  attr_accessible :name

  delegate :data_source, :accessible_to, :connect_with, :to => :schema

  def self.add_search_permissions(current_user, search)
    search.build do
      any_of do
        without :security_type_name, Dataset.security_type_name
        account_ids = current_user.accessible_account_ids
        with :instance_account_ids, account_ids unless account_ids.blank?
      end

      any_of do
        without :security_type_name, "ChorusView"
        with :member_ids, current_user.id
        with :public, true
      end
    end
  end

  def self.with_name_like(name)
    if name.present?
      where("name ILIKE ?", "%#{name}%")
    else
      scoped
    end
  end

  def self.list_order
    order("lower(replace(datasets.name,'_',''))")
  end

  def self.tables
    where("type LIKE '%Table'")
  end

  def self.views
    views_tables.where("type LIKE '%View'")
  end

  def self.views_tables
    where("type <> 'ChorusView'")
  end

  def self.chorus_views
    where(:type => 'ChorusView')
  end

  def self.filter_by_name(datasets, name)
    if name.present?
      datasets.select do |dataset|
        dataset.name =~ /#{name}/i
      end
    else
      datasets
    end
  end

  def should_reindex?
    !stale? && !skip_search_index
  end

  def self.find_and_verify_in_source(dataset_id, user)
    dataset = find(dataset_id)
    unless dataset.verify_in_source(user)
      raise ActiveRecord::RecordNotFound
    end
    dataset
  end

  def query_setup_sql
    ""
  end

  def all_rows_sql(limit = nil)
    Arel::Table.new(name).project('*').take(limit).to_sql
  end

  def entity_type_name
    'dataset'
  end

  def type_name
    'Dataset'
  end

  def update_active_tables_and_views_counter_cache_on_schema
    if changed_attributes.include?('stale_at')
      if stale?
        Schema.decrement_counter(:active_tables_and_views_count, schema_id)
      else
        Schema.increment_counter(:active_tables_and_views_count, schema_id)
      end
    end
  end

  def skip_active_table_and_views_counter_cache_for_chorus_views
    if is_a?(ChorusView)
      if destroyed?
        Schema.increment_counter(:active_tables_and_views_count, schema_id)
      else
        Schema.decrement_counter(:active_tables_and_views_count, schema_id)
      end
    end
  end
end