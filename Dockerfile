FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install PyTorch CPU first to prevent downloading the massive ~2.5GB CUDA runtime
RUN pip install torch==2.9.1 torchvision==0.24.1 --index-url https://download.pytorch.org/whl/cpu

# Install the rest of the requirements
RUN pip install -r requirements.txt

# Install serving libraries
RUN pip install gunicorn celery redis django-cors-headers

COPY . .
