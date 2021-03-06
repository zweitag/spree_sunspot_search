Spree::Product.class_eval do
  searchable do
    boolean :is_active, :using => :is_active?

    conf = Spree::Search::SpreeSunspot.configuration

    conf.fields.each do |field|
      if field.class == Hash
        field = { :opts => {} }.merge field
        send field[:type], field[:name], field[:opts]
      else
        text(field)
      end
    end

    # manually setup taxons
    integer :taxon_ids, :multiple => true, :references => Spree::Taxon
    integer :taxon, :multiple => true do
      taxons.map(&:id)
    end

    # this is the facet that is used in the taxon display
    # the name is a bit ugly, but it keeps us DRY by using PRODUCT_SHOW_FACETS
    string :taxon_name_facet, :multiple => true do
      taxons.map(&:name)
    end

    conf.option_facets.each do |option|
      string "#{option}_facet", :multiple => true do
        get_option_values(option.to_s).map(&:presentation)
      end
    end

    conf.property_facets.each do |prop|
      string "#{prop}_facet", :multiple => true do
        property(prop.to_s)
      end
    end

    conf.other_facets.each do |method|
      string "#{method}_facet", :multiple => true do
        send(method)
      end
    end

    if respond_to?(:stores)
      integer :store_ids, :multiple => true, :references => Store
    end

  end

  def is_active?
    !deleted_at && available_on &&
      (available_on <= Time.zone.now) &&
        (Spree::Config[:allow_backorders] || count_on_hand > 0)
  end

  private

  def price_range
    max = 0
    Spree::Search::SpreeSunspot.configuration.price_ranges.each do |range, name|
      return name if range.include?(price)
      max = range.max if range.max > max
    end
    I18n.t(:price_and_above, :price => max)
  end

  def get_option_values(option_name)
    # in the next 1.1.x release this should be replaced with the option value accessors

    sql = <<-eos
      SELECT DISTINCT ov.id, ov.presentation
      FROM spree_option_values AS ov
      LEFT JOIN spree_option_types AS ot ON (ov.option_type_id = ot.id)
      LEFT JOIN spree_option_values_variants AS ovv ON (ovv.option_value_id = ov.id)
      LEFT JOIN spree_variants AS v ON (ovv.variant_id = v.id)
      LEFT JOIN spree_products AS p ON (v.product_id = p.id)
      WHERE (ot.name = '#{option_name}' AND p.id = #{self.id});
    eos
    Spree::OptionValue.find_by_sql(sql)
  end
end
