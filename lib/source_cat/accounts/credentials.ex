defmodule SourceCat.Accounts.Credentials do
  require Ash.Query
  alias SourceCat.Accounts.{User, Attempt}

  def valid_pin?(pin), do: is_binary(pin) and Regex.match?(~r/\A[0-9]{6,12}\z/, pin)
  def hash(pin, salt), do: :crypto.pbkdf2_hmac(:sha256, pin, salt, 600_000, 32) |> Base.encode16()

  def verify(pin, salt, expected),
    do: Plug.Crypto.secure_compare(hash(pin, salt), String.upcase(expected))

  def fresh_name do
    adjectives =
      ~w(Bright Gentle Brave Happy Calm Swift Clever Sunny Kind Quiet Nice Cute Cool Warm Fresh Sweet Bold Lucky Tiny Soft Wise Quick Merry Jolly Shy Neat Fair Wild Cozy Chill Royal Noble Pink Blue Gold Red Silver Amber Magic Young)

    fruits =
      ~w(Mango Apple Pear Peach Plum Kiwi Lime Lemon Orange Banana Cherry Grape Melon Papaya Guava Berry Fig Date Lychee Pomelo Apricot Coconut Durian Olive Tomato Longan Quince Satsuma Loquat Damson)

    available_name(adjectives, fruits, 0)
  end

  defp available_name(_, _, 80),
    do: raise("All generated names are in use. Please expand the name dictionary.")

  defp available_name(adjectives, fruits, attempts) do
    name = Enum.random(adjectives) <> " " <> Enum.random(fruits)
    if by_name(name), do: available_name(adjectives, fruits, attempts + 1), else: name
  end

  def by_name(name) do
    User
    |> Ash.Query.filter(name_key == ^String.downcase(String.trim(name)))
    |> Ash.read_one!(authorize?: false)
  end

  def signup(name, pin) do
    cond do
      not valid_pin?(pin) ->
        {:error, {422, "Use a PIN with 6–12 digits."}}

      not is_binary(name) or not Regex.match?(~r/\A[A-Za-z]+ [A-Za-z]+\z/, name) ->
        {:error, {422, "Generate your username first."}}

      true ->
        salt = Base.encode16(:crypto.strong_rand_bytes(32))

        User
        |> Ash.Changeset.for_create(:create, %{
          name: name,
          name_key: String.downcase(name),
          salt: salt,
          password_hash: hash(pin, salt)
        })
        |> Ash.create(authorize?: false)
    end
  end

  def login(name, pin, ip_key) do
    name = String.downcase(String.trim(to_string(name)))
    keys = ["name:" <> name, "ip:" <> ip_key]

    cond do
      blocked?(keys) ->
        {:error, {429, "Too many attempts. Try again in 15 minutes."}}

      not valid_pin?(pin) or String.length(name) > 80 ->
        fail_login(keys)

      true ->
        user = by_name(name)

        valid? =
          if user,
            do: verify(pin, user.salt, user.password_hash),
            else: verify(pin, "unknown-account", String.duplicate("0", 64))

        if valid? do
          clear(keys)
          {:ok, user}
        else
          fail_login(keys)
        end
    end
  end

  defp fail_login(keys) do
    failed(keys)
    {:error, {401, "Incorrect username or PIN."}}
  end

  def change_pin(user, current, new, ip_key) do
    with true <- valid_pin?(new), {:ok, _} <- login(user.name, current, ip_key) do
      salt = Base.encode16(:crypto.strong_rand_bytes(32))

      user
      |> Ash.Changeset.for_update(:update, %{
        salt: salt,
        password_hash: hash(new, salt),
        auth_version: user.auth_version + 1
      })
      |> Ash.update(authorize?: false)
    else
      false -> {:error, {422, "Use a PIN with 6–12 digits."}}
      error -> error
    end
  end

  def blocked?(keys) do
    now = System.system_time(:second)

    Enum.any?(keys, fn key ->
      a = Ash.get!(Attempt, key, authorize?: false, not_found_error?: false)
      a && a.failures >= 8 && now - a.last_at < 900
    end)
  end

  def failed(keys) do
    import Ecto.Query
    now = System.system_time(:second)
    cutoff = now - 900
    timestamp = DateTime.utc_now()

    conflict =
      from a in Attempt,
        update: [
          set: [
            failures:
              fragment("CASE WHEN ? > ? THEN ? + 1 ELSE 1 END", a.last_at, ^cutoff, a.failures),
            last_at: ^now,
            updated_at: ^timestamp
          ]
        ]

    Enum.each(keys, fn key ->
      SourceCat.Repo.insert_all(
        Attempt,
        [%{id: key, failures: 1, last_at: now, inserted_at: timestamp, updated_at: timestamp}],
        on_conflict: conflict,
        conflict_target: [:id],
        log: false
      )
    end)
  end

  def clear(keys) do
    import Ecto.Query
    SourceCat.Repo.delete_all(from a in Attempt, where: a.id in ^keys)
    :ok
  end
end
