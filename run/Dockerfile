FROM python:3.9-slim

# Allow statements and log messages to immediately appear in the Knative logs
ENV PYTHONUNBUFFERED True

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy local code to the container image.
COPY main.py .

# Port 8080 is the default for Cloud Run
EXPOSE 8080

# Run the web service on container startup.
CMD ["python", "main.py"]
