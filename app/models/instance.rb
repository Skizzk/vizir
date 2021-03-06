class Instance < ActiveRecord::Base
  attr_accessible :entity_id, :metric_id, :provider_id, :details
  attr_reader :unique_name

  serialize :details, JSON

  validates :entity_id, :provider_id, :metric_id,
    :presence => true

  belongs_to :entity, :inverse_of => :instances
  belongs_to :metric, :inverse_of => :instances
  belongs_to :provider, :inverse_of => :instances

  has_many :graphs_instances, :inverse_of => :instance, :dependent => :destroy
  has_many :graphs, :through => :graphs_instances

  scope :incl_assocs, includes(:metric, :entity, :provider)
  scope :join_assocs, joins(:metric, :entity, :provider)
  scope :wo_graph, includes(:graphs).where(:graphs => {:id => nil})

  def fetch_values(start, finish)
    options = details.clone
    options["entity"] = entity.name
    options["start"] = start
    options["end"] = finish

    data = {
      "id" => id,
      "name" => title,
      "unit" => metric.unit,
      "data_type" => metric.data_type,
      "data" => provider.get_values(options)
    }
  end

  def title
    if metric.title
      replace_vars(metric.title, details)
    else
      metric.name
    end
  end

  def unique_name
    details.values.sort.join("|")
  end

  private

  # TODO factorize that with Graph
  def replace_vars(string, vars)
    new_string = string.dup
    var_names = new_string.scan(/\$(\S+)/).flatten
    unless var_names.empty?
      var_names.each do |var_name|
        new_string.gsub!("$#{var_name}", vars[var_name])
      end
    end
    new_string
  end

  def destroy_orphaned_graph(graph)
    if graph.instances.count == 0
      graph.destroy
    end
  end
end
