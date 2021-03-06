# coding: utf-8

require 'test_helper'
require 'fluent/plugin/out_lookup'

class LookupOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    dir = File.dirname(__FILE__)
    @nonexisting_file = "#{dir}/tobeornottobe.csv"
    @correct_file = "#{dir}/correct.csv"
    @duplicates_file = "#{dir}/duplicates.csv"
    @empty_file = "#{dir}/empty.csv"
  end

  def create_driver(conf, tag = 'test')
    Fluent::Test::OutputTestDriver.new(
      Fluent::LookupOutput, tag
    ).configure(conf)
  end


  def test_configure_on_success


    # All set
    d = create_driver(%[
      strict true
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
      output_field key2
    ])

    assert_equal 'lookup.', d.instance.add_tag_prefix
    assert_equal ['key1'],    d.instance.field
    assert_equal true, d.instance.strict
    assert_equal @correct_file, d.instance.table_file


    # "Strict" omitted
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
      output_field key2
    ])

    assert_equal 'lookup.', d.instance.add_tag_prefix
    assert_equal ['key1'],    d.instance.field
    assert_equal false, d.instance.strict
    assert_equal @correct_file, d.instance.table_file


    # "output_field" omitted
    d = create_driver(%[
      strict true
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
    ])

    assert_equal 'lookup.', d.instance.add_tag_prefix
    assert_equal ['key1'],    d.instance.field
    assert_equal true, d.instance.strict
    assert_equal @correct_file, d.instance.table_file


    # File with duplicates in non-strict mode
    d = create_driver(%[
      strict false
      add_tag_prefix lookup.
      table_file #{@duplicates_file}
      field key1
      output_field key2
    ])

    assert_equal 'lookup.', d.instance.add_tag_prefix
    assert_equal ['key1'],    d.instance.field
    assert_equal false, d.instance.strict
    assert_equal @duplicates_file, d.instance.table_file


    # Empty file in non-strict mode
    d = create_driver(%[
      strict false
      add_tag_prefix lookup.
      table_file #{@empty_file}
      field key1
      output_field key2
    ])

    assert_equal 'lookup.', d.instance.add_tag_prefix
    assert_equal ['key1'],    d.instance.field
    assert_equal false, d.instance.strict
    assert_equal @empty_file, d.instance.table_file

  end

  def test_configure_on_failure
    # when mandatory keys not set
    assert_raise(Fluent::ConfigError) do
      create_driver(%[
        blah blah
      ])
    end

    # 'field' is missing
    assert_raise(Fluent::ConfigError) do
      create_driver(%[
        strict true
        add_tag_prefix lookup.
        table_file #{@correct_file}
        output_field key2
      ])
    end

    # 'table_file' is missing
    assert_raise(Fluent::ConfigError) do
      create_driver(%[
        strict true
        add_tag_prefix lookup.
        field key1
        output_field key2
      ])
    end

    # 'table_file' is not readable in strict mode
    assert_raise(Fluent::ConfigError) do
      create_driver(%[
        strict true
        add_tag_prefix lookup.
        table_file #{@nonexisting_file}
        field key1
        output_field key2
      ])
    end

    # 'table_file' is not readable in non-strict mode
    assert_raise(Fluent::ConfigError) do
      create_driver(%[
        strict false
        add_tag_prefix lookup.
        table_file #{@nonexisting_file}
        field key1
        output_field key2
      ])
    end

    # 'table_file' contains duplicates in strict mode
    assert_raise(Fluent::ConfigError) do
      create_driver(%[
        strict true
        add_tag_prefix lookup.
        table_file #{@duplicates_file}
        field key1
        output_field key2
      ])
    end

    # 'table_file' is empty in strict mode
    assert_raise(Fluent::ConfigError) do
      create_driver(%[
        strict true
        add_tag_prefix lookup.
        table_file #{@empty_file}
        field key1
        output_field key2
      ])
    end

  end


  def test_unit_create_lookup_table

    # Correct file
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
      output_field key2
    ])

    table = d.instance.create_lookup_table(@correct_file)
    assert_equal({"foo"=>"bar", "nicolas"=>"cage", "input"=>"output", "1"=>"one", "two"=>"2"}, table)

    # With duplicates
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@duplicates_file}
      field key1
      output_field key2
    ])

    table = d.instance.create_lookup_table(@duplicates_file)
    assert_equal({"foo"=>"bar", "nicolas"=>"cage", "input"=>"output", "1"=>"one", "two"=>"2"}, table)

    # Empty file
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@empty_file}
      field key1
      output_field key2
    ])

    table = d.instance.create_lookup_table(@empty_file)
    assert_equal({}, table)

  end


  def test_unit_handle_row
    # Correct row
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
    ])

    table = {}
    d.instance.handle_row(table, ["foo", "bar"])
    assert_equal({"foo"=>"bar"}, table)

    # Too small row
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
    ])

    table = {}
    assert_raise do d.instance.handle_row(table, ["foo"]) end
    assert_equal({}, table)

    # Too large row non strict
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
    ])

    table = {}
    d.instance.handle_row(table, ["foo", "bar", "baz"])
    assert_equal({"foo" => "bar"}, table)

    # Too large row strict
    d = create_driver(%[
      add_tag_prefix lookup.
      strict true
      table_file #{@correct_file}
      field key1
    ])

    table = {}
    assert_raise do d.instance.handle_row(table, ["foo", "bar", "baz"]) end
    assert_equal({}, table)


    # Too duplicate row non strict
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
    ])

    table = {}
    d.instance.handle_row(table, ["foo", "bar"])
    d.instance.handle_row(table, ["foo", "baz"])
    assert_equal({"foo" => "baz"}, table)


    # Too duplicate row strict
    d = create_driver(%[
      add_tag_prefix lookup.
      strict true
      table_file #{@correct_file}
      field key1
    ])

    table = {}
    d.instance.handle_row(table, ["foo", "bar"])
    assert_raise do d.instance.handle_row(table, ["foo", "baz"]) end
    assert_equal({"foo" => "bar"}, table)
  end


  def test_emit_with_output_field
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
      output_field key2
    ])

    record = {
      'key1' => "nicolas",
      'foo' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'cage', emits[0][2]['key2']
  end

  def test_emit_with_output_field_no_correspondance
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
      output_field key2
    ])

    record = {
      'key1' => "myvalue",
      'foo' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'myvalue', emits[0][2]['key2']
  end

  def test_emit_without_output_field
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
    ])

    record = {
      'key1' => "nicolas",
      'foo' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'cage', emits[0][2]['key1']
  end



  def test_emit_nested_without_output_field
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field nested.key1
    ])

    record = {
      'nested' => {
        'key1' => "nicolas",
      },
      'foo' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'cage', emits[0][2]['nested']['key1']
  end


  def test_emit_nested_with_non_existing_output_field
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field nested.key1
      output_field new.foo
    ])

    record = {
      'nested' => {
        'key1' => "nicolas",
      },
      'foo' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'cage', emits[0][2]['new']['foo']
  end

  # Checks that the record is not modified if the input_field is not found
  def test_emit_nested_with_non_existing_input_field
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field nested.key1
      output_field new.foo
    ])

    record = {
      'foo' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal nil, emits[0][2]['nested']
    assert_equal nil, emits[0][2]['new']
    assert_equal 'bar', emits[0][2]['foo']
  end

  # Checks that the record is not modified if the input_field is not found
  def test_emit_nested_with_partial_output_structure
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field nested.key1
      output_field new.foo
    ])

    record = {
      'foo' => "bar",
      'nested' => {
        'key1' => "nicolas",
      },
      'new' => {
        'field1' => "value1",
        'field2' => "value2"
      }
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'nicolas', emits[0][2]['nested']['key1']
    assert_equal 'cage', emits[0][2]['new']['foo']
    assert_equal 'value1', emits[0][2]['new']['field1']
    assert_equal 'value2', emits[0][2]['new']['field2']

  end

  # Checks that the record is not modified if the input_field is not found
  def test_emit_nested_with_non_existing_input_field_no_output
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field nested.key1
    ])

    record = {
      'foo' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal nil, emits[0][2]['nested']
  end

  def test_emit_without_output_field_no_correspondance
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field key1
    ])

    record = {
      'key1' => "myvalue",
      'foo' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'myvalue', emits[0][2]['key1']
  end

  def test_emit_rename_key
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field nicolas
      rename_key true
    ])

    record = {
      'nicolas' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'bar', emits[0][2]['cage']
    assert_equal nil, emits[0][2]['nicolas']
  end

  def test_emit_rename_key_erase
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field nicolas
      rename_key true
    ])

    record = {
      'nicolas' => "bar",
      'cage' => "foo"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'bar', emits[0][2]['cage']
    assert_equal nil, emits[0][2]['nicolas']
  end

  def test_emit_rename_key_nested
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field nested.nicolas
      rename_key true
    ])

    record = {
      'nested' => {
        'nicolas' => "bar",
      }
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'bar', emits[0][2]['nested']['cage']
    assert_equal nil, emits[0][2]['nested']['nicolas']
  end

  def test_emit_rename_key_not_existing
    d = create_driver(%[
      add_tag_prefix lookup.
      table_file #{@correct_file}
      field dummy
      rename_key true
    ])

    record = {
      'nicolas' => "bar"
    }

    d.run { d.emit(record) }
    emits = d.emits

    assert_equal 1,           emits.count
    assert_equal 'lookup.test', emits[0][0]
    assert_equal 'bar', emits[0][2]['nicolas']
  end

end
