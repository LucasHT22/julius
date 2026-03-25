module ParseInput

using CSV, DataFrames, XLSX, JSON3

export parse_csv, parse_excel, parse_json, extract_numeric_columns

function parse_csv(path::String)::DataFrame
    CSV.read(path, DataFrames; missingstring=["", "NA", "N/A", "null", "NULL"])
end

function parse_excel(path::String; sheet=1)::DataFrame
    xf = XLSX.readxlsx(path)
    sh = XLSX.sheetnames(xf)[sheet]
    DataFrame(XLSX.eachtablerow(xf[sh]))
end

function parse_json(json_str::String)::Vector{Float64}
    obj = JSON3.read(json_str)
    if obj isa JSON3.Array && !isempty(obj) && obj[1] isa Number
        return Float64[x for x in obj if x isa Number]
    end
    if obj isa JSON3.Object && haskey(obj, :data)
        arr = obj[:data]
        if arr isa JSON3.Array && !isempty(arr) && arr[1] isa Number
            return Float64[x for x in arr if x isa Number]
        end
    end
    if obj isa JSON3.Array && !isempty(obj) && obj[1] isa JSON3.Object
        sample = obj[1]
        numeric_key = nothing
        for (k, v) in pairs(sample)
            v isa Number && (numeric_key = k; break)
        end
         isnothing(numeric_key) && error("No numeric field found in JSON objects.")
        return Float64[row[numeric_key] for row in obj if row[numeric_key] isa Number]
    end
    error("Unsupported JSON structure.")
end

function extract_numeric_columns(df::DataFrame)::Dict{String, Vector{Float64}}
    result = Dict{String, Vector{Float64}}()
    for col in names(df)
        T = eltype(df[!, col])
        if T <: Union{Missing, Number}
            vals = Float64[x for x in df[!, col]
                           if !ismissing(x) && isfinite(Float64(x)) && Float64(x) > 0]
            length(vals) >= 10 && (result[col] = vals)
        end
    end
    result
end

end # module