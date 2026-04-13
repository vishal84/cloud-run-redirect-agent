import os
from google.adk.cli.fast_api import get_fast_api_app
import logging

logging.basicConfig(level=logging.DEBUG)

app = get_fast_api_app(
    agents_dir=".",
    web=False,
    a2a=True,
    host="0.0.0.0",
    port=int(os.getenv("PORT", 8080)),
)

if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
