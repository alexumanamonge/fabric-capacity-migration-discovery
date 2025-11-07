# Common Issues and Solutions

## Issue: [CANNOT_MERGE_TYPE] Error in Step 5

### Error Message
```
❌ Error collecting capacity data: [CANNOT_MERGE_TYPE] Can not merge type `ArrayType` and `StringType`.
```

### Root Cause
This error occurs when trying to concatenate DataFrames with incompatible column types. The `Admins` column in the capacity data is an array type, but when creating the "Non Premium (Shared)" record, there was a type mismatch.

### Solution Applied (Fixed in Latest Version)
The notebook has been updated to convert the `Admins` column to JSON string representation before concatenating:

```python
# Convert Admins column to string to avoid type conflicts
if 'Admins' in df_capacities.columns:
    df_capacities['Admins'] = df_capacities['Admins'].apply(
        lambda x: json.dumps(x) if x is not None else None
    )

# Now both records have the same type (string)
new_record = pd.DataFrame([{
    "Capacity Id": "-1",
    "Capacity Name": "Non Premium (Shared)",
    "Sku": "Shared",
    "Region": "N/A",
    "State": "Active",
    "Admins": json.dumps(["N/A"])  # Converted to JSON string
}])
```

### If You're Still Seeing This Error

1. **Update the notebook**: Pull the latest version from the repository
   ```bash
   git pull origin main
   ```

2. **Re-upload to Fabric**: Delete the old notebook and upload the new version

3. **Alternative workaround**: If you can't update, modify Step 5 cell directly in Fabric:
   - Find the line: `"Admins": ["N/A"]`
   - Add the conversion code shown above before creating `new_record`

### Verification
After the fix, Step 5 should complete with:
```
✓ Collected [X] Premium/Fabric capacities

Capacity Summary:
[SKU breakdown]

✓ Capacities data saved to Lakehouse
```

---

## Other Common Type Mismatch Errors

### Issue: Upstream Datasets or Users Column Errors

**Symptoms:** Similar merge errors in Step 8 (Semantic Models)

**Solution:** The notebook already handles this by converting arrays to JSON strings:
```python
df_semantic_models["Upstream Datasets"] = df_semantic_models["Upstream Datasets"].apply(
    lambda x: json.dumps(x) if x and x != "[]" else None
)
df_semantic_models["Users"] = df_semantic_models["Users"].apply(
    lambda x: json.dumps(x) if x and x != "[]" else None
)
```

### Issue: Date/DateTime Format Errors

**Symptoms:** Cannot write datetime columns to Delta Lake

**Solution:** Convert to string format:
```python
df['Created Date'] = df['Created Date'].astype(str)
```

---

## Prevention Tips

When working with Fabric notebooks and Delta Lake:

1. ✅ **Always convert complex types** (arrays, objects) to JSON strings
2. ✅ **Check column dtypes** before concatenating DataFrames
3. ✅ **Use `ignore_index=True`** when concatenating
4. ✅ **Handle null values** explicitly (fillna, replace)
5. ✅ **Test with small datasets** first before running on full tenant

---

## Issue: DirectQuery Partition Has 0 Datasource References

### Error Message
```
❌ Error creating semantic model: Dataset_Import_FailedToImportDataset
DirectQuery partition 'Capacities' has '0' datasource reference(s) in its expression which is not allowed.
```

### Root Cause
When creating a DirectLake semantic model, each partition must have:
1. An `expressionSource` reference to the data source
2. The `lakehouse` parameter passed to `create_semantic_model_from_bim()`

### Solution Applied (Fixed in Latest Version)
The notebook has been updated to include both requirements:

```python
# In partition definitions, add expressionSource
"partitions": [
    {
        "name": "Capacities",
        "mode": "directLake",
        "source": {
            "type": "entity",
            "entityName": "Capacities",
            "expressionSource": "DatabaseQuery",  # ← Added this
            "schemaName": "dbo"
        }
    }
]

# When creating the model, pass lakehouse parameter
labs.create_semantic_model_from_bim(
    dataset=semantic_model_name,
    bim_file=bim_model,
    lakehouse=lakehouse  # ← Added this parameter
)
```

### Verification
After the fix, Step 10 should complete with:
```
Creating semantic model...
✓ Semantic model 'Capacity Migration Analysis' created successfully
```

---

## Issue: DirectQuery Partition Has 0 Datasource References (Persistent)

### Error Message
```
❌ Error creating semantic model: Dataset_Import_FailedToImportDataset
DirectQuery partition 'Capacities' has '0' datasource reference(s) in its expression which is not allowed.
```

### Root Cause
When using `create_semantic_model_from_bim()`, the model is created **without** an established lakehouse connection, even though DirectLake partitions require one. The lakehouse connection can only be established after the model exists, but the model creation fails if partitions lack datasource references.

### Solution Applied (Fixed in Latest Version - v1.0.4)
Changed approach from using BIM definition to using semantic-link-labs helper functions that properly establish the lakehouse connection first:

```python
# NEW APPROACH: Create blank model with lakehouse, then add tables
labs.create_blank_semantic_model(
    dataset=semantic_model_name,
    lakehouse=lakehouse  # Connection established immediately
)

# Then add tables one by one
labs.add_table_to_direct_lake_semantic_model(
    dataset=semantic_model_name,
    table_name="Capacities",
    lakehouse_table_name="Capacities",
    lakehouse=lakehouse
)

# Add relationships
labs.add_relationship_to_semantic_model(
    dataset=semantic_model_name,
    from_table="Workspaces",
    from_column="Capacity Id",
    to_table="Capacities",
    to_column="Capacity Id"
)

# Add measures
labs.add_measure_to_semantic_model(
    dataset=semantic_model_name,
    table_name="Capacities",
    measure_name="Total Capacities",
    expression="COUNTROWS(Capacities)",
    format_string="#,0"
)
```

This approach:
1. ✅ Creates model with lakehouse connection from the start
2. ✅ Adds tables incrementally with proper datasource references
3. ✅ Avoids the BIM parsing and datasource reference errors

### Verification
After the fix, Step 10 should complete with:
```
Creating semantic model...
Creating blank semantic model...
✓ Blank semantic model 'Capacity Migration Analysis' created
Adding tables to semantic model...
✓ All tables added to semantic model
Creating relationships...
✓ Relationships created
Adding measures...
✓ Measures added

✓ Semantic model 'Capacity Migration Analysis' created successfully
```

### Note
Step 11 is no longer needed for establishing the lakehouse connection (it's done in Step 10), but it still handles report creation.

---

**Last Updated:** November 2025  
**Fixed in Version:** v1.0.4


