import express from "express"

const app = express()
const PORT = process.env.PORT || 49180

app.get("/fake", async (req, res, next) => {
    try {
        const startAt = new Date().toISOString()
        const startMs = performance.now()

        await new Promise(r => setTimeout(r, 20 + Math.random() * 30))

        const endMs = performance.now()
        const endAt = new Date().toISOString()

        res.status(200).json({
            startAt,
            endAt,
            elapsedMs: (endMs - startMs).toFixed(2)
        })
    } catch (err) {
        next(err)
    }
})

app.use((err, req, res, next) => {
    console.error(`[Error] ${err.message}`)
    const errCode = err.statusCode || 500
    res.status(errCode).json(
        { message: err.message || "Internal Server Error" }
    )
})

app.listen(PORT, () => {
    console.log(`Hi from node:${PORT}`)
})



