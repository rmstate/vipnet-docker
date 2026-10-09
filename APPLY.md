# Применение обновления

Этот архив содержит только файлы проекта, которые нужно обновить или добавить. Он не содержит `backup/`, `local/`, ключей, DST или файлов состояния ViPNet.

Из корня репозитория сначала проверьте состояние:

```bash
git status --short
git ls-files backup/
```

Сделайте локальную резервную копию только изменяемых текстовых файлов, затем распакуйте архив поверх репозитория. Не добавляйте `backup/` в Git.

```bash
stamp=$(date +%Y%m%d-%H%M%S)
mkdir -p "$HOME/vipnet-docker-text-backup-$stamp"
for f in README.md SECURITY.md docs/01-installation.md docs/02-keys-and-startup.md docs/03-routing-and-connectivity.md docs/04-troubleshooting.md scripts/route.sh scripts/validate.sh; do
  if [ -f "$f" ]; then mkdir -p "$HOME/vipnet-docker-text-backup-$stamp/$(dirname "$f")"; cp -a "$f" "$HOME/vipnet-docker-text-backup-$stamp/$f"; fi
done
# Замените путь на фактический путь скачанного vipnet-docker-update.tar.gz
tar -xzf "$HOME/Downloads/vipnet-docker-update.tar.gz"
chmod +x scripts/route.sh scripts/validate.sh
bash scripts/validate.sh
git diff --check
git status --short
git diff --stat
```

Проверьте `git diff` до коммита. `scripts/route.sh` не следует запускать `apply` повторно для миграции, пока не проверены старые правила предыдущей версии. Старые правила в общих цепочках `FORWARD` и `POSTROUTING` новый `remove` не удаляет автоматически.


## Что проверяет валидатор

`bash scripts/validate.sh` проверяет синтаксис Bash, наличие документации, локальные Markdown-ссылки и ключевые защитные проверки `route.sh`. Он не меняет маршруты и firewall и не заменяет проверку `check` и тест соединения в вашей лабораторной сети. Не запускайте `apply` или `remove` без проверки текущих маршрутов и правил.
