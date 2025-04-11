# Use the appropriate Python version
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy application code
COPY . /app

# Install dependencies
RUN pip install --no-cache-dir flask gunicorn

# Expose port
EXPOSE 80

# Run the application using Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:80", "app:app"]
