## Как поднять 🛠️

#### 0. Локальная инфраструктура
Для начала необходимо иметь установленный minikube и поднять его, а также открыть тунель:
```sh
minikube start
minikube tunnel
```

Кроме того, приложение настроено на работу на домене `bighw.com`. Для корректной работы на локально машине необходимо в `/etc/hosts` добавить:
```txt
127.0.0.1       bighw.com
```

Также в корне папке есть `docker-compose.yaml`. С помощью него поднимаем необходимые для БД:
```sh
docker compose up --build -d
```
#### 1. Поднимаем Prometheus
В папке репозитория выполняем команду:
```sh
kubectl apply -f ./addons/prometheus.yaml
```

Далее просим minikube прокинуть prometheus для использование дашборда:
```sh
minikube service prometheus -n istio-system
```

*Как проверить, что запустилось корректно?*
Должен открыться интерфейс Prometheus :)
#### 2. Поднимаем приложение
В папке репозитория выполняем команду:
```sh
helmfile -e devel -n bighw apply
```


*Как проверить, что поднялось корректно?*

Находясь в папке репозитория, сделаем seed данных в БД:
```sh
docker exec -i muffinDB psql -U root -d muffin_wallet < scripts/seed_data.sql
```

Далее делаем запрос:
```sh
curl -s -X 'POST' 'http://bighw.com/v1/muffin-wallet/32354edf-4466-4599-8363-d14a386309dc/transaction' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{ "to_muffin_wallet_id": "386b8757-f4b3-4280-8910-5b54a7959ace", "amount": 1 }'
```
В ответе не должно быть ошибок.

### Запросы для получения нужных метрик 
*Уточнение*: все примеры ниже подразумевают, что был сделан seed данных, как описано выше. 

#### 1. Количество запросов в секунду по каждому методу

```sh 
sum(rate(http_server_requests_seconds_count{app_kubernetes_io_name="muffin-wallet"}[1m])) by (method)
```

*Как проверить работу*?
Нагоним трафик с операциями по созданию и проверим, что значение для POST увеличивается. Например, вот так:
```sh
for i in $(seq 1 100); curl -s -o /dev/null -X 'POST' 'http://bighw.com/v1/muffin-wallet/32354edf-4466-4599-8363-d14a386309dc/transaction' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{ "to_muffin_wallet_id": "386b8757-f4b3-4280-8910-5b54a7959ace", "amount": 1 }'
```

#### 2. Количество ошибок в логах приложение (накопительный итог со старта)

```sh
sum(logback_events_total{app_kubernetes_io_name="muffin-wallet", level="error"})
```

*Как проверить работу?*
Вручную убьем деплой `muffin-currency`:
```sh
kubectl delete deploy -n bighw muffin-currency 
```

И сделаем запрос:
```sh
curl -s -X 'POST' 'http://bighw.com/v1/muffin-wallet/32354edf-4466-4599-8363-d14a386309dc/transaction' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{ "to_muffin_wallet_id": "386b8757-f4b3-4280-8910-5b54a7959ace", "amount": 1 }'
```
Число ошибок должно увеличиться

P.S. чтобы вернуть кластер в нормальное состояние выполним: 
```sh
helmfile -e devel -n bighw sync
```

### 3. 99-й персентиль времени ответа HTTP (обработка запросов).

```sh
histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket{app_kubernetes_io_name="muffin-wallet"}[5m])) by (le))
```

*Как проверить?*
Запускаем трафик:
```sh
while sleep 0.05; do curl -s -o /dev/null -X 'POST' 'http://bighw.com/v1/muffin-wallet/32354edf-4466-4599-8363-d14a386309dc/transaction' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{ "to_muffin_wallet_id": "386b8757-f4b3-4280-8910-5b54a7959ace", "amount": 1 }'; done;
```

Затем замедляем 10% ответов от `muffin-currency`, добавив эти строки в `muffin-currency/virtual-service.yaml`:
```yaml
# muffin-currency/virtual-service.yaml
fault:
	delay:
	percentage:
		value: 10.0
	fixedDelay: 3s
```

Применяем изменения:
```sh
helmfile -e devel -n bighw apply
```

Спустя некоторое время увидим повышение значения до 3 сек :)

#### 4. Количество активных соединений к базе данных PostgreSQL

Получение значения:
```sh
sum(hikaricp_connections_active{app_kubernetes_io_name="muffin-wallet"})
```

Но само значение не всегда очень полезно. Полезнее бывает посмотреть изменение в общем использовании connections:
```sh
rate(hikaricp_connections_usage_seconds_sum{app_kubernetes_io_name="muffin-wallet"}[1m])
```

*Как проверить?*
Нагоняем трафик с нескольких терминалов (например, 3) с помощью команды:
```sh
while sleep 0.05; do curl -s -o /dev/null -X 'POST' 'http://bighw.com/v1/muffin-wallet/32354edf-4466-4599-8363-d14a386309dc/transaction' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{ "to_muffin_wallet_id": "386b8757-f4b3-4280-8910-5b54a7959ace", "amount": 1 }'; done;
```
Смотрим на увеличение значения.
