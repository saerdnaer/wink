# frozen_string_literal: true

# Renders JSON-LD (schema.org vocabulary) documents, see JsonLd.
module JsonLdRendering
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 100
  MAX_PER_PAGE = 500

  private

  def render_jsonld(document, status: :ok)
    render json: JsonLd.with_context(document), status: status, content_type: JsonLd::CONTENT_TYPE
  end

  # Renders a paginated schema.org/ItemList (?page=, ?per_page=).
  # Pagination is also exposed via X-Total-Count and Link (rel=next/prev) headers.
  def render_list(relation, name)
    page = [ params[:page].to_i, 1 ].max
    per_page = params[:per_page].to_i
    per_page = DEFAULT_PER_PAGE unless per_page.positive?
    per_page = [ per_page, MAX_PER_PAGE ].min
    total = relation.count
    offset = (page - 1) * per_page

    set_pagination_headers(page, per_page, total)

    elements = relation.limit(per_page).offset(offset).each_with_index.map do |record, index|
      { "@type" => "ListItem", "position" => offset + index + 1, "item" => yield(record) }
    end

    render_jsonld({
                    "@type" => "ItemList", "@id" => request.original_url, "name" => name,
                    "numberOfItems" => total, "itemListElement" => elements
                  })
  end

  def set_pagination_headers(page, per_page, total)
    response.set_header("X-Total-Count", total.to_s)
    response.set_header("X-Page", page.to_s)
    response.set_header("X-Per-Page", per_page.to_s)

    links = []
    links << "<#{page_url(page - 1)}>; rel=\"prev\"" if page > 1
    links << "<#{page_url(page + 1)}>; rel=\"next\"" if page * per_page < total
    response.set_header("Link", links.join(", ")) if links.any?
  end

  def page_url(page)
    url_for(request.query_parameters.merge(page: page, only_path: false))
  end
end
