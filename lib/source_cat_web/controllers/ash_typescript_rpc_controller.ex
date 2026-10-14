defmodule SourceCatWeb.AshTypescriptRpcController do
  use SourceCatWeb, :controller

  def run(conn, params) do
    result = AshTypescript.Rpc.run_action(:source_cat, conn, params)
    json(conn, result)
  end

  def validate(conn, params) do
    result = AshTypescript.Rpc.validate_action(:source_cat, conn, params)
    json(conn, result)
  end
end
