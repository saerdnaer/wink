# frozen_string_literal: true

# Read-only, unauthenticated GraphQL endpoint (POST /graphql).
class GraphqlController < ActionController::API
  def execute
    result = WinkSchema.execute(
      params[:query],
      variables: ensure_hash(params[:variables]),
      operation_name: params[:operationName],
      context: {}
    )
    render json: result
  rescue JSON::ParserError
    render json: { errors: [ { message: "invalid variables" } ] }, status: :bad_request
  end

  private

  def ensure_hash(variables)
    case variables
    when String then variables.present? ? JSON.parse(variables) || {} : {}
    when Hash then variables
    when ActionController::Parameters then variables.to_unsafe_hash
    when nil then {}
    else raise ArgumentError, "Unexpected parameter: #{variables}"
    end
  end
end
