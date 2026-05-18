local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

-- Get current state or initialize
local bucket = redis.call('HMGET', key, 'tokens', 'lastRefillTs')
local tokens = tonumber(bucket[1])
local lastRefillTs = tonumber(bucket[2])
-- Try to consume a token
local allowed = 0

-- return if no key found
if tokens == nil then
    tokens = -1
    return tostring(allowed) .. "," .. tostring(tokens)
end

-- Calculate token refill
local elapsed = math.max(0, now - lastRefillTs)
local refill = elapsed * refill_rate
tokens = math.min(capacity, tokens + refill)
lastRefillTs = now

if tokens >= 1 then
    tokens = tokens - 1
    allowed = 1
end

-- Update state
redis.call('HMSET', key, 'tokens', tokens, 'lastRefillTs', lastRefillTs)

-- Return result: allowed (1 or 0) and remaining tokens
return tostring(allowed) .. "," .. tostring(tokens)
