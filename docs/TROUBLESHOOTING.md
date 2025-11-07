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

## Issue: Property ExpressionSource Cannot Be Found

### Error Message
```
❌ Error creating semantic model: Workload_FailedToParseFile
Property ExpressionSource of object "partition <oii>Capacities</oii> in table <oii>Capacities</oii>" refers to an object which cannot be found
```

### Root Cause
The `expressionSource` property was incorrectly added as a direct string property in the partition source definition. For DirectLake partitions in Fabric, this property should not be included as a simple property - it needs to be properly defined as an expression object or omitted entirely.

### Solution Applied (Fixed in Latest Version)
Remove the `expressionSource` property from partition definitions. DirectLake partitions only need:

```python
"partitions": [
    {
        "name": "Capacities",
        "mode": "directLake",
        "source": {
            "type": "entity",
            "entityName": "Capacities",
            "schemaName": "dbo"  # Only these 3 properties needed
        }
    }
]
```

The lakehouse connection is established later in Step 11 using:
```python
labs.directlake.update_direct_lake_model_lakehouse_connection(
    dataset=semantic_model_name,
    lakehouse=lakehouse
)
```

### Verification
After the fix, Step 10 should complete with:
```
Creating semantic model...
✓ Semantic model 'Capacity Migration Analysis' created successfully
```

---

**Last Updated:** November 2025  
**Fixed in Version:** v1.0.3

