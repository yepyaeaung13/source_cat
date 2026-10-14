defmodule SourceCat.Accounts do
  use Ash.Domain

  resources do
    resource SourceCat.Accounts.Session
    resource SourceCat.Accounts.User
    resource SourceCat.Accounts.Attempt
  end
end
