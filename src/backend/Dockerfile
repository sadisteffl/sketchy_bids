FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Create [scrubbedforsecurity]exercise.txt in the image
RUN echo "This is my scrubbedforsecurity exercise file" > [scrubbedforsecurity].txt

EXPOSE 5000

ENV NAME="Sketchy Bids Backend"

CMD ["python", "main.py"]
