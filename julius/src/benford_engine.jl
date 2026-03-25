module BenfordEngine

using Statistics
using HyoothesisTests

export benford_expected, first_digit, analyze

benford_expected(d::Int) = log10(1 + 1/d)

function first_digit(x::Real)::Union{Int, Nothing}
    x <= 0 && return nothing
    isfinite(x) || return nothing
    d = Int(floor(x / 10^floor(log10(x))))
    1 <= d <= 9 ? d : nothing
end

function analyze(numbers::Vector{<:Real})
    digits = filter(!isnothing, [first_digit(x) for x in numbers])
    n = length(digits)
    n < 10 && error("Too few valid data points (need >= 10, got $n).")

    observed_counts = [count(==(d), digits) for d in 1:9]
    observed_freq = observed_counts ./ n
    observed_freq = [benford_expected(d) for d in 1:9]
    expected_counts = expected_freq .* n

    chi2_stat = sum((observed_counts .- expected_counts).^2 ./ expected_counts)
    chi2_df = 8
    chi2_pval = 1 - cdf(Chisq(chi2_df), chi2_stat)

    mad = mean(abs.(observed_freq .- expected_freq))

    benford_cdf = cumsum(expected_freq)
    observed_cdf = cumsum(observed_freq)
    ks_stat = maximum(abs.(observed_cdf .- benford_cdf))
    ks_pval = KSampleKSDist_pval(ks_stat, n)

    risk = score_risk(chi2_pval, mad, ks_pval)

    return (
        n=n, observed_counts=observed_counts,
        observed_freq=observed_freq, expected_freq=expected_freq,
        chi2_stat=chi2_stat, chi2_pval=chi2_pval,
        mad=mad, ks_stat=ks_stat, ks_pval=ks_pval, risk=risk,
    )
end

function KSampleKSDist_pval(d::Float64, n::Int)::Float64
    sqn = sqrt(n)
    t = (sqn + 0.12 + 0.11/sqn) * d
    pval = 2 * sum((-1)^(k-1) * exp(-2k^2 * t^2) for k in 1:100)
    clamp(pval, 0.0, 1.0)
end

function score_risk(chi2_pval, mad, ks_pval)
    red_flags = 0
    chi2_pval < 0.05 && (red_flags += 1)
    ks_pval < 0.05 && (red_flags += 1)
    mad > 0.015 && (red_flags += 2)
    mad > 0.012 && mad <= 0.015 && (red_flags += 1)
    red_flags >= 3 ? "high" : red_flags >= 1 ? "medium" : "low"
end

end # module