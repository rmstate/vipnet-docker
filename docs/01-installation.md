# 1. Получение дистрибутива и сборка

## Требования
- Arch Linux / Omarchy с Docker Engine;
- пакет ViPNet Client for Linux x64, который вы вправе использовать;
- DST и параметры подключения для вашей тестовой среды.

Исходный кейс использовал ViPNet Client `5.0.0-7877`, amd64. Другие версии могут вести себя иначе.

## Где получить пакет
Откройте [официальный сайт Infotecs](https://infotecs.ru/) и найдите раздел ViPNet Client / загрузок для Linux. Если дистрибутив не доступен для свободной загрузки, запросите его у администратора организации или через официальный канал поставки/поддержки. Не используйте случайные файлообменники. Проверьте источник и контрольную сумму, если производитель её публикует.

## Куда положить пакет
В этом примере используется имя пакета из лаборатории. Если у вас другое имя, замените путь в командах на фактический:

```bash
cd ~/Projects/vipnet-docker-lab
mkdir -p local/package

file ~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb
dpkg-deb --info ~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb
```

## Извлечение файлов
Текущий Dockerfile копирует уже извлечённое содержимое из `local/package/`, а не устанавливает `.deb` через `dpkg -i`. Поэтому выполните:

```bash
cd ~/Projects/vipnet-docker-lab
dpkg-deb -x ~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb local/package/
```

Проверьте структуру:

```bash
find local/package -maxdepth 3 -type d | sort | head -80
```

`local/package/` содержит проприетарные файлы и не должен публиковаться. Не запускайте пакетные скрипты ViPNet на хосте в качестве обходного пути.

## Сборка
```bash
cd ~/Projects/vipnet-docker-lab
sudo docker build -t vipnet5-lab:test .
sudo docker image inspect vipnet5-lab:test --format '{{.Id}}'
```

Не публикуйте образ в открытый registry: он содержит файлы вендора.

## Проверка перед публикацией
```bash
find . -type f \( -name '*.dst' -o -name '*.deb' -o -name '*.enc' -o -name '*.pem' -o -name '*.key' -o -name '*.crt' \) -not -path './.git/*' -print
git status --short
```

Проверьте все staged-файлы перед коммитом. Если секрет попал в историю Git, простого удаления файла недостаточно.
