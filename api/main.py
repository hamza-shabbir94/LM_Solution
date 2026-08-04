import time

from fastapi import FastAPI

app = FastAPI()


@app.get("/hello")
async def hello():
    return {"message": f"Hello!"}


@app.get("/ready")
@app.get("/alive")
async def ok():
    return {"message": "ok"}


@app.on_event("startup")
async def startup_event():
    time.sleep(5)
