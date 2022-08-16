# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
defmodule SchemaWeb.SchemaController do
  @moduledoc """
  The Event Schema API.
  """
  use SchemaWeb, :controller

  require Logger

  @verbose "_mode"
  @spaces "_spaces"
  @extensions "extensions"

  # -------------------
  # Event Schema API's
  # -------------------

  # {
  #   @api {get} /api/version Get Version
  #   @apiName GetVersion
  #   @apiDescription This API returns the OCSF schema version.
  #   @apiGroup Schema
  #   @apiVersion 1.0.0
  #   @apiPermission none
  #
  #   @apiExample {curl} Example usage:
  #     curl https://schema.ocsf.io/api/version
  #
  #   @apiSuccess {String} version The OCSF schema version, using Semantic Versioning Specification (SemVer) format.
  #  
  #   @apiSuccessExample Success-Response:
  #       HTTP/2 200 OK
  #       {
  #         "version": "0.16.0"
  #       }
  # }
  @doc """
  Renders the schema version.
  """
  @spec version(Plug.Conn.t(), any) :: Plug.Conn.t()
  def version(conn, _params) do
    version = %{:version => Schema.version()}
    send_json_resp(conn, version)
  end

  # {
  #   @api {get} /api/data_types Get Data Types
  #   @apiName DataTypes
  #   @apiDescription This API returns the OCSF schema data types.
  #   @apiGroup Schema
  #   @apiVersion 1.0.0
  #   @apiPermission none
  # }
  @doc """
  Renders the data types.
  """
  @spec data_types(Plug.Conn.t(), any) :: Plug.Conn.t()
  def data_types(conn, _params) do
    send_json_resp(conn, Schema.export_data_types())
  end

  # {
  #   @api {get} /api/extensions Get Extensions
  #   @apiName Extensions
  #   @apiDescription This API returns the OCSF schema extensions.
  #   @apiGroup Schema
  #   @apiVersion 1.0.0
  #   @apiPermission none
  # }
  @doc """
  Returns the schema extensions.
  """
  @spec extensions(Plug.Conn.t(), any) :: Plug.Conn.t()
  def extensions(conn, _params) do
    send_json_resp(conn, Schema.extensions())
  end

  # {
  #   @api {get} /api/profiles Ger Profiles
  #   @apiName Profiles
  #   @apiDescription This API returns the OCSF schema profiles.
  #   @apiGroup Schema
  #   @apiVersion 1.0.0
  #   @apiPermission none
  # }
  @doc """
  Returns the schema profiles.
  """
  @spec profiles(Plug.Conn.t(), any) :: Plug.Conn.t()
  def profiles(conn, _params) do
    send_json_resp(conn, Schema.profiles())
  end

  # {
  #   @api {get} /export/schema Export Schema
  #   @apiName ExportSchema
  #   @apiDescription This API returns the schema defintions, including data types, objects, and classes.
  #   @apiGroup Export
  #   @apiVersion 1.0.0
  #   @apiPermission none
  #
  #   @apiExample {curl} Example usage:
  #     curl https://schema.ocsf.io/export/schema
  #
  #   @apiSuccess {Object} classes The OCSF schema classes.
  #   @apiSuccess {Object} objects The OCSF schema obejcts.
  #   @apiSuccess {Object} types The OCSF schema data types.
  #   @apiSuccess {String} version The OCSF schema version.
  #  
  #   @apiSuccessExample Success-Response:
  #       HTTP/2 200 OK
  #       {
  #         "classes": {...},
  #         "objects": {...},
  #         "types"  : {...},
  #         "version": "0.16.0"
  #       }
  # }
  @spec export_schema(Plug.Conn.t(), any) :: Plug.Conn.t()
  def export_schema(conn, params) do
    profiles = parse_profiles(params["profiles"])
    data = parse_options(params[@extensions]) |> Schema.export_schema(profiles)
    send_json_resp(conn, data)
  end

  # {
  # @api {get} /api/categories/:name Request Category classes
  # @apiName Category
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # @apiParam {String} name Category name
  # }
  @doc """
  Renders categories or the classes in a given category.
  """
  @spec categories(Plug.Conn.t(), map) :: Plug.Conn.t()
  def categories(conn, %{"id" => id} = params) do
    try do
      case category_classes(params) do
        nil ->
          send_json_resp(conn, 404, %{error: "Not Found: #{id}"})

        data ->
          send_json_resp(conn, data)
      end
    rescue
      e ->
        Logger.error("Unable to load the classes for category: #{id}. Error: #{inspect(e)}")
        send_json_resp(conn, 500, %{error: "Error: #{e[:message]}"})
    end
  end

  # {
  # @api {get} /api/categories Request Categories
  # @apiName Categories
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # }
  def categories(conn, params) do
    send_json_resp(conn, categories(params))
  end

  @spec categories(map) :: map
  def categories(params) do
    parse_options(params[@extensions]) |> Schema.categories()
  end

  @spec category_classes(map) :: map | nil
  def category_classes(%{"id" => id} = params) do
    extension = params["extension"]
    extensions = parse_options(params[@extensions])

    Schema.category(extensions, extension, id)
  end

  # {
  #   @api {get} /export/category/:name Export Category
  #   @apiName ExportCategory
  #   @apiDescription This API returns the classes defined in the given category.
  #   @apiGroup Export
  #   @apiVersion 1.0.0
  #   @apiPermission none
  #   @apiParam {String} name Category name
  #
  #   @apiExample {curl} Example usage:
  #     curl https://schema.ocsf.io/export/category/system
  #
  #   @apiSuccess {String} caption The category caption.
  #   @apiSuccess {String} description The category description.
  #   @apiSuccess {Number} uid The category unique identifier.
  #   @apiSuccess {Object} classes The category classes.
  #   @apiError UserNotFound The category <code>name</code> was not found.
  #
  #   @apiSuccessExample Success-Response:
  #       HTTP/2 200 OK
  #       {
  #         "caption": "System Activity"
  #         "description": "System Activity events."
  #         "uid": 1
  #         "classes": {...}
  #       }
  #
  #   @apiErrorExample {json} Error-Response:
  #       HTTP/2 404 Not Found
  #       {
  #           "error": "The category 'test' was not found."
  #       }
  # }
  @doc """
  Exports the classes in a given category.
  """
  @spec export_category(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_category(conn, %{"id" => id} = params) do
    try do
      extension = params["extension"]
      extensions = parse_options(params[@extensions])

      case Schema.export_category(extensions, extension, id) do
        nil ->
          send_json_resp(conn, 404, %{error: "The category '#{id}' was not found."})

        category ->
          case parse_profiles(params["profiles"]) do
            nil ->
              send_json_resp(conn, category)

            profiles ->
              category =
                Map.update!(category, :classes, fn classes ->
                  Schema.apply_profiles(classes, profiles, MapSet.size(profiles))
                end)

              send_json_resp(conn, category)
          end
      end
    rescue
      e ->
        Logger.error("Unable to load the classes for category: #{id}. Error: #{inspect(e)}")
        send_json_resp(conn, 500, %{error: "Error: #{e[:message]}"})
    end
  end

  # {
  # @api {get} /api/dictionary Request Dictionary
  # @apiName Dictionary
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # }
  @doc """
  Renders the attribute dictionary.
  """
  @spec dictionary(Plug.Conn.t(), any) :: Plug.Conn.t()
  def dictionary(conn, params) do
    data = dictionary(params) |> remove_links(:attributes)

    send_json_resp(conn, data)
  end

  @doc """
  Renders the dictionary.
  """
  @spec dictionary(map) :: map
  def dictionary(params) do
    parse_options(params[@extensions]) |> Schema.dictionary()
  end

  # {
  # @api {get} /api/base_event Request Base Event
  # @apiName Base Event
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # }
  @doc """
  Renders the base event attributes.
  """
  @spec base_event(Plug.Conn.t(), any) :: Plug.Conn.t()
  def base_event(conn, params) do
    base = Schema.class(:base_event) |> add_objects(params)

    send_json_resp(conn, base)
  end

  # {
  # @api {get} /api/classes/:type Request Class
  # @apiName Class
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # @apiParam {String} type Event class type name, for example: `mem_usage`
  # }
  @doc """
  Renders event classes.
  """
  @spec classes(Plug.Conn.t(), any) :: Plug.Conn.t()
  def classes(conn, %{"id" => id} = params) do
    extension = params["extension"]

    try do
      case Schema.class(extension, id) do
        nil ->
          send_json_resp(conn, 404, %{error: "Not Found: #{id}"})

        data ->
          class = Schema.delete_see_also(data) |> add_objects(params)
          send_json_resp(conn, class)
      end
    rescue
      e ->
        Logger.error("Unable to get class: #{id}. Error: #{inspect(e)}")
        send_json_resp(conn, 500, %{error: "Error: #{e[:message]}"})
    end
  end

  # {
  # @api {get} /api/classes Request all Classes
  # @apiName Class
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # }
  def classes(conn, params) do
    classes =
      Enum.map(classes(params), fn {_name, class} ->
        Schema.reduce_class(class)
      end)

    send_json_resp(conn, classes)
  end

  # {
  # @api {get} /export/classes Export all classes
  # @apiName Class
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # }
  def export_classes(conn, params) do
    profiles = parse_profiles(params["profiles"])
    classes = parse_options(params[@extensions]) |> Schema.export_classes(profiles)
    send_json_resp(conn, classes)
  end

  @spec classes(map) :: map
  def classes(params) do
    extensions = parse_options(params[@extensions])

    case parse_profiles(params["profiles"]) do
      nil ->
        Schema.classes(extensions)

      profiles ->
        Schema.classes(extensions, profiles)
    end
  end

  # {
  # @api {get} /api/objects/:type Request Object
  # @apiName Object
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # @apiParam {String} type Object type name, for example: `container`
  # }
  @doc """
  Renders objects.
  """
  @spec objects(Plug.Conn.t(), map) :: Plug.Conn.t()
  def objects(conn, %{"id" => id} = params) do
    try do
      case object(params) do
        nil ->
          send_json_resp(conn, 404, %{error: "Not Found: #{id}"})

        data ->
          send_json_resp(conn, add_objects(data, params))
      end
    rescue
      e ->
        Logger.error("Unable to get object: #{id}. Error: #{inspect(e)}")
        send_json_resp(conn, 500, %{error: "Error: #{e[:message]}"})
    end
  end

  # {
  # @api {get} /api/objects Request all Objects
  # @apiName Objects
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # }
  def objects(conn, params) do
    objects =
      Enum.map(objects(params), fn {_name, map} ->
        Map.delete(map, :_links) |> Schema.delete_attributes()
      end)

    send_json_resp(conn, objects)
  end

  # {
  # @api {get} /export/objects Export all objects
  # @apiName Objects
  # @apiGroup Schema
  # @apiVersion 1.0.0
  # @apiPermission none
  # }
  def export_objects(conn, params) do
    profiles = parse_profiles(params["profiles"])
    objects = parse_options(params[@extensions]) |> Schema.export_objects(profiles)
    send_json_resp(conn, objects)
  end

  @spec objects(map) :: map
  def objects(params) do
    parse_options(params[@extensions]) |> Schema.objects()
  end

  @spec object(map) :: map() | nil
  def object(%{"id" => id} = params) do
    extension = params["extension"]
    parse_options(params[@extensions]) |> Schema.object(extension, id)
  end

  # ---------------------------------
  # Validation and translation API's
  # ---------------------------------

  # {
  # @api {post} /api/translate?_mode=:mode Translate Event Data
  # @apiName Translate
  # @apiGroup Data
  # @apiVersion 1.0.0
  # @apiPermission none
  # @apiParam {Number=1,2,3} _mode  Controls how the attribute names and enumerated values are translated
  # @apiParam {String} _spaces  Controls how the spaces in the translated attribute names are handled
  # @apiParam {JSON} event  The event to be translated as a JSON object
  #
  # @apiParamExample {json} Request-Example:
  #     {
  #       "class_uid": 1002,
  #       "activity_id": 1,
  #       "severity_id": 1,
  #       "message": "This is an important message"
  #     }
  #
  # @apiSuccessExample {json} Success-Response:
  #     {
  #       "class_uid": "Entity Audit",
  #       "message": "This is an important message",
  #       "activity_id": "Created",
  #       "severity_id": "Informational"
  #     }
  # }
  @spec translate(Plug.Conn.t(), map) :: Plug.Conn.t()
  def translate(conn, data) do
    options = [spaces: data[@spaces], verbose: verbose(data[@verbose])]

    case data["_json"] do
      nil ->
        # Translate a single events
        data =
          Map.delete(data, @verbose)
          |> Map.delete(@spaces)
          |> Schema.Translator.translate(options)

        send_json_resp(conn, data)

      list when is_list(list) ->
        # Translate a list of events
        translated = Enum.map(list, fn data -> Schema.Translator.translate(data, options) end)
        send_json_resp(conn, translated)

      other ->
        # some other json data
        send_json_resp(conn, other)
    end
  end

  # {
  # @api {post} /api/validate Validate Event Data
  # @apiName Validate
  # @apiGroup Data
  # @apiVersion 1.0.0
  # @apiPermission none
  # @apiParam {JSON} event  The event or events to be translated. A single event is encoded as a JSON object and multiple events are encoded as JSON array of object.
  #
  # @apiSuccess {JSON} An empty JSON object
  #      HTTP/2 200 OK
  #      {}
  # }
  @spec validate(Plug.Conn.t(), map) :: Plug.Conn.t()
  def validate(conn, data) do
    case data["_json"] do
      nil ->
        # Validate a single events
        send_json_resp(conn, Schema.Inspector.validate(data))

      list when is_list(list) ->
        # Validate a list of events
        result = Enum.map(list, fn data -> Schema.Inspector.validate(data) end)
        send_json_resp(conn, result)

      other ->
        # some other json data
        send_json_resp(conn, %{:error => "The data does not look like an event", "data" => other})
    end
  end

  # --------------------------
  # Request sample data API's
  # --------------------------

  # {
  # @api {get} /sample/base_event Request Base Event data
  # @apiName Base Event Sample
  # @apiGroup Sample
  # @apiVersion 1.0.0
  # @apiPermission none
  # @apiSuccess {JSON} The randomly generated sample data
  # }
  @doc """
  Returns a base event sample.
  """
  @spec sample_event(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sample_event(conn, _params) do
    send_json_resp(conn, Schema.event(:base_event))
  end

  # {
  # @api {get} /sample/classes/:name Request Event data
  # @apiName Event Sample
  # @apiGroup Sample
  # @apiVersion 1.0.0
  # @apiPermission none
  # @apiParam {String} name Event class name
  # @apiSuccess {JSON} The randomly generated sample data
  # }
  @doc """
  Returns an event sample for the given name.
  """
  @spec sample_class(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sample_class(conn, %{"id" => id} = options) do
    extension = options["extension"]
    profiles = parse_profiles(options["profiles"])

    try do
      case Schema.class(extension, id) do
        nil ->
          send_json_resp(conn, 404, %{error: "Not Found: #{id}"})

        class ->
          event =
            case Map.get(options, @verbose) do
              nil ->
                Schema.generate_event(class, profiles)

              verbose ->
                Schema.generate_event(class, profiles)
                |> Schema.Translator.translate(
                  spaces: options[@spaces],
                  verbose: verbose(verbose)
                )
            end

          send_json_resp(conn, event)
      end
    rescue
      e ->
        Logger.error("Unable to generate sample for class: #{id}. Error: #{inspect(e)}")
        send_json_resp(conn, 500, %{error: "Error: #{e[:message]}"})
    end
  end

  # {
  # @api {get} /sample/objects/:name Request Object data
  # @apiName Object Sample
  # @apiGroup Sample
  # @apiVersion 1.0.0
  # @apiPermission none
  # @apiParam {String} name Object name
  # @apiSuccess {JSON} json The randomly generated sample data
  # }
  @doc """
  Returns an object sample data for the given name.
  """
  @spec sample_object(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sample_object(conn, %{"id" => id} = options) do
    extension = options["extension"]

    try do
      case Schema.object(extension, id) do
        nil ->
          send_json_resp(conn, 404, %{error: "Not Found: #{id}"})

        data ->
          send_json_resp(conn, Schema.generate(data))
      end
    rescue
      e ->
        Logger.error("Unable to generate sample for object: #{id}. Error: #{inspect(e)}")
        send_json_resp(conn, 500, %{error: "Error: #{e[:message]}"})
    end
  end

  defp send_json_resp(conn, error, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(error, Jason.encode!(data))
  end

  defp send_json_resp(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(data))
  end

  defp remove_links(data) do
    data
    |> Schema.delete_links()
    |> remove_links(:attributes)
  end

  defp remove_links(data, key) do
    case data[key] do
      nil ->
        data

      list ->
        updated =
          Enum.map(list, fn {k, v} ->
            %{k => Schema.delete_links(v)}
          end)

        Map.put(data, key, updated)
    end
  end

  defp add_objects(data, %{"objects" => "1"}) do
    objects = update_objects(Map.new(), data[:attributes])

    if map_size(objects) > 0 do
      Map.put(data, :objects, objects)
    else
      data
    end
    |> remove_links()
  end

  defp add_objects(data, _params) do
    remove_links(data)
  end

  defp update_objects(objects, attributes) do
    Enum.reduce(attributes, objects, fn {_name, field}, acc ->
      update_object(field, acc)
    end)
  end

  defp update_object(field, acc) do
    case field[:type] do
      "object_t" ->
        type = field[:object_type] |> String.to_atom()

        if Map.has_key?(acc, type) do
          acc
        else
          object = Schema.object(type)
          Map.put(acc, type, remove_links(object)) |> update_objects(object[:attributes])
        end

      _other ->
        acc
    end
  end

  defp verbose(option) when is_binary(option) do
    case Integer.parse(option) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp verbose(_), do: 0

  defp parse_options(nil), do: MapSet.new()
  defp parse_options(""), do: MapSet.new()
  defp parse_options(options), do: String.split(options, ",") |> MapSet.new()

  defp parse_profiles(nil), do: nil
  defp parse_profiles(""), do: MapSet.new()
  defp parse_profiles(profiles), do: String.split(profiles, ",") |> MapSet.new()
end
