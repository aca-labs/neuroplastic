class Neuroplastic::Elastic(T)
  COUNT  = "count"
  HITS   = "hits"
  TOTAL  = "total"
  SCORE  = ["_score"]
  ID     = "_id"
  SOURCE = "_source"
  TYPE   = "type"

  # Index defaults to rethinkdb table name
  @index : String = T.table_name

  # Document type defaults to class name without namespace
  @type : String = T.class.name.split("::").last

  def initialize(index : String? = nil, type : String? = nil)
    @type = type unless type.nil?
    @index = index unless index.nil?
  end

  @@client : Neuroplastic::Client | Nil

  # Yields the elastic search client
  def client
    @@client ||= Neuroplastic::Client.new
  end

  # Safely build the query
  def query(params = {} of Symbol => String, filters = nil)
    builder = Query.new(params)
    builder.filter(filters) unless filters.nil?

    builder
  end

  # Performs a count query against an index
  def count(builder)
    query = generate_body(builder)

    # Simplify the query
    body = query[:body].to_h.reject(:from, :size, :sort)
    simplified = query.merge({body: body})
    client.count(simplified)[COUNT].as_i
  end

  # Query elasticsearch with a query builder object
  def search(builder)
    _search(builder)
  end

  # Query elasticsearch with a query builder object, accepts a formatter block
  # Allows annotation/conversion of records using data from the model.
  # Nils are removed from the list.
  def search(builder, &block : Proc(T, (T | Nil)))
    _search(builder, block)
  end

  private def _search(builder, block = nil)
    query = generate_body(builder)
    result = client.search(query.to_h)

    raw_records = get_records(result).to_a
    records = block ? raw_records.compact_map { |r| block.call r } : raw_records

    total = result_total(result: result, builder: builder, records: records, raw: raw_records)
    {
      total:   total,
      results: records,
    }
  end

  # Ensures the results total is accurate
  private def result_total(result, builder, records, raw = nil)
    total = result[HITS][TOTAL]?.try(&.as_i) || 0

    records_size = records.size
    raw_size = raw.try(&.size) || records_size

    total = total - (records_size - raw_size) # adjust for compaction

    offset = builder.offset
    limit = builder.limit

    # We check records against limit (pre-compaction) and total against actual result length
    # Worst case senario is there is one additional request for results at an offset that returns no results.
    # The total results number will be accurate on the final page of results from the clients perspective.
    total = records_size + offset if raw_size < limit && total > (offset + records_size)
    total
  end

  # Filters off results that do not match the document type.
  # Returns a collection of records pulled in from the db.
  private def get_records(result)
    ids = result.dig?(HITS, HITS).try(&.as_a.compact_map { |hit|
      doc_type = hit[SOURCE][TYPE].as_s
      doc_type == @type ? hit[ID].as_s : nil
    })
    ids ? T.find_all(ids) : [] of T
  end

  def generate_body(builder)
    opt = builder.build

    queries = opt[:query]
    sort = (opt[:sort]? || [] of Array(String)) + SCORE
    filters = opt[:filters]? || [] of Hash(String, String)
    index = builder.index || @index

    {
      index: index,
      body:  {
        query: {
          bool: {
            must:   queries,
            filter: {
              bool: {
                must: filters,
              },
            },
          },
        },
        sort: sort,
        from: opt[:offset],
        size: opt[:limit],
      },
    }
  end
end
