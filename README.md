fluent-plugin-lookup
====================

(Yet another Fluentd plugin)

What
----

Allows to replace record values for specific keys, using a lookup table from a *CSV* file.

How
---

You basically want to define :
- Input field : **field**.
- Output field : **output_field** (omitting this parameter will replace *input* field value).
- Lookup table CSV file : **table_file** (two columns per row, separated by a comma).
- Sanity check, raises error if empty, malformed file or duplicates entries inside the file : **strict** (omitting this parameter will default to *false*).

Use this filter multiple times if you need to repalce multiple fields.

Examples
========

This is our *lookup.csv* file :

```
value,other_value
nicolas,cage
input,output
1,one
two,2
```

Example 1
---------

```
<match *.test>
    type lookup
    add_tag_prefix lookup.
    table_file /usr/share/my/lookup.csv
    field key1
    output_field key2
</match>
```

Example of records :
```
{
    'key1' => "nicolas",
    'foo' => "bar"
}
```
... will output :
```
{
    'key1' => "nicolas",
    'key2' => "cage",
    'foo' => "bar"
}
```

Example 2
---------

```
<match *.test>
    type lookup
    add_tag_prefix lookup.
    table_file /usr/share/my/lookup.csv
    field key1
</match>
```

Example of records :
```
{
    'key1' => "nicolas",
    'foo' => "bar"
}
```
... will output :
```
{
    'key1' => "cage",
    'foo' => "bar"
}
```

Since *output_field* is not defined, the input *field* value is replaced.