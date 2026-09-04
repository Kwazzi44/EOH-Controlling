-- EOH fill calculator
-- Расчет точной дозировки жидкости через транспозер

local calculator = {}

function calculator.createPlan(amount, rate)
    if not rate or rate <= 0 then
        return nil, "invalid rate"
    end

    local full = math.floor(amount / rate)
    local rest = amount - (full * rate)

    return {
        total = amount,
        rate = rate,
        fullTransfers = full,
        lastTransfer = rest
    }
end

return calculator
