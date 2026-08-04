FROM python:3.9.1-buster

WORKDIR /app

COPY . .

RUN pip install -r requirements.txt

CMD ["python", "-m", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "80", "--timeout-keep-alive", "10"]
