# Установка и сборка образа

Руководство подготавливает локальные файлы ViPNet Client 5 и собирает Docker-образ. Оно не выполняет импорт ключей и не подключает VPN автоматически.

## Требования

- Arch Linux / Omarchy с работающим Docker Engine;
- `dpkg-deb` для распаковки Debian-пакета;
- разрешённый к использованию пакет ViPNet Client for Linux x86-64;
- конфигурация и ключевой материал для тестового контура.

В исходной лаборатории использовался `vipnetclient_gost_amd64_5.0.0-7877.deb` (версия `5.0.0-7877`). У других релизов могут отличаться зависимости и поведение.

## Получение пакета

Получайте пакет с [официального сайта ИнфоТеКС](https://infotecs.ru/) или из одобренного корпоративного хранилища. Не используйте случайные файлообменники.

Пример пути:

```text
~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb
```

Проверьте тип и метаданные:

```bash
file ~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb
dpkg-deb --info ~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb
```

## Подготовка локальных файлов

Из корня репозитория:

```bash
cd ~/Projects/vipnet-docker-lab
mkdir -p local/package
dpkg-deb -x ~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb local/package/
find local/package -maxdepth 3 -type d | sort | head -80
```

`Dockerfile` копирует содержимое `local/package/` в образ; исходный `.deb` внутри образа не устанавливается через `dpkg`. Это важно: распаковка пакета не равна полноценной установке системных зависимостей.

`local/package/` содержит проприетарные файлы поставщика и исключён из Git. Не отправляйте эти файлы в публичный репозиторий или публичный registry.

## Сборка

```bash
sudo docker build -t vipnet5-lab:test .
sudo docker image inspect vipnet5-lab:test --format '{{.Id}}'
```

Успешная сборка подтверждает, что Docker собрал образ, но не подтверждает запуск клиента или сетевую связность. Текущая команда по умолчанию — `vipnetclient --help`. Продолжайте с [Ключей и запуска](02-keys-and-startup.md).
