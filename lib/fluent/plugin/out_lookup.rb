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
    config_param :rename_key, :bool, :default => false

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

      @assign_method = method(:assign)
      @assign_self_method = method(:assign_self)
      @return_method = method(:return)
      @rename_method = method(:rename)

      if (field.nil? || table_file.nil?) 
        raise ConfigError, "lookup: Both 'field', and 'table_file' are required to be set."
      end

      @lookup_table = create_lookup_table(table_file)
      @field = field.split(".")

      if (rename_key)
        @filter_method = method(:filter_rename_key)
        return
      end

      if (output_field.nil?)
        @filter_method = method(:filter_no_output)
      else
        @output_field = output_field.split(".")
        @filter_method = method(:filter_with_output)
      end


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

    def assign_self(record, key, value)
      assign(record, key, record[key])
    end

    def assign(record, key, value)
      record[key] = process(value) || value
    end

    def return(record, key, value_nouse) 
      return record[key]
    end

    def rename(record, key, value_nouse)
      new_key = process(key) || return
      field_value = record[key]
      record.delete(key)
      record[new_key] = field_value
    end
    

    def filter_record(tag, time, record)
      super(tag, time, record)
      @filter_method.call(record)
    end

    # Same input/output : Get and set (dig once)
    def filter_no_output(record)
      dig_cb(record, @field, nil, false, @assign_self_method)
    end

    # Different input/output : Get, then set (dig twice)
    def filter_with_output(record)
      value = dig_cb(record, @field, nil, false, @return_method)
      if (!value.nil?)
        dig_cb(record, @output_field, value, true, @assign_method)
      end
    end

    # Rename key (will NOT copy or move the field, just rename the key)
    def filter_rename_key(record)
      value = dig_cb(record, @field, nil, false, @rename_method)
    end

    # Generic function to dig into map. 
    def dig_cb(record, path, value, alter, cb)
      digged_record = record
      path.each_with_index {|key, index|
        # If enabled, creates new path in the record
        if (!digged_record.has_key?(key))
          if (!alter) 
            return nil
          end
          digged_record[key] = {}
        end

        if (index == path.length - 1)
          return cb.call(digged_record, key, value)
        else
          digged_record = digged_record[key]
        end
      }
      return nil
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
