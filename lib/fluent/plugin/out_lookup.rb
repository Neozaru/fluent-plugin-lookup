# coding: utf-8
require "csv"

module Fluent
  class LookupOutput < Output
    include Fluent::HandleTagNameMixin

    Fluent::Plugin.register_output('lookup', self)

    config_param :table_file, :string, :default => nil
    config_param :field, :string, :default => nil
    config_param :output_field, :string, :default => nil
    config_param :strict, :bool, :default => false

    def handle_row(lookup_table, row)
      if (row.length < 2)
        return handle_row_error(row, "Too few columns : #{row.length} instead of 2")
      end

      # If too much columns
      if (strict && row.length > 2)
        return handle_row_error(row, "Too much columns : #{row.length} instead of 2")
      end

      # If duplicates
      if (strict && lookup_table.has_key?(row[0]))
        return handle_row_error(row, "Duplicate entry")
      end

      lookup_table[row[0]] = row[1]

    end


    def create_lookup_table(file)
      lookup_table = {}
      CSV.foreach(file) do |row|
        handle_row(lookup_table, row)
      end

      if (strict && lookup_table.length == 0)
        raise ConfigError, "Lookup file is empty"
      end

      return lookup_table
    rescue Errno::ENOENT => e
      handle_file_err(file, e)
    rescue Errno::EACCES => e
      handle_file_err(file, e)
    end


    def configure(conf)
      super

      if (field.nil? || table_file.nil?) 
        raise ConfigError, "lookup: Both 'field', and 'table_file' are required to be set."
      end

      @lookup_table = create_lookup_table(table_file)
      @field = field
      @output_field = output_field || field

    end

    def emit(tag, es, chain)
      es.each { |time, record|
        t = tag.dup
        filter_record(t, time, record)
        Engine.emit(t, time, record)
      }

      chain.next
    end

    private

    def filter_record(tag, time, record)
      super(tag, time, record)
      if (not record.has_key?(@field))
        return
      end
      record[@output_field] = process(record[@field]) || record[@field]
    end

    def process(value)
      return @lookup_table[value]
    end


    def handle_row_error(row, e)
      raise ConfigError, "Error at row #{row} : #{e}"
    end


    def handle_file_err(file, e)
      raise ConfigError, "Unable to open file '#{file}' : #{e.message}"
    end

  end
end
