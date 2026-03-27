# 🐧 Ubuntu Server Initializer

새 우분투 서버를 YAML 설정 한 장으로 자동 세팅하는 도구입니다.

---

## 개요

- **목표:** 새 Ubuntu 22.04/24.04 LTS 서버를 필요한 패키지, 서비스, 사용자, 방화벽 설정까지 한 번에 자동 설치
- **방식:** `config.yaml`에 원하는 구성 작성 → `setup.sh` 실행 → 끝
- **지향:** 단순, 빠름, 재사용 가능, 커뮤니티 YAML 공유

---

## 사용법

```bash
# 1. config.yaml 편집 (원하는 구성 작성)
vim config.yaml

# 2. setup.sh 실행
chmod +x setup.sh
sudo ./setup.sh
```

---

## YAML 설정 스펙 (`config.yaml`)

### 전체 구조

```yaml
# ===== 서버 기본 정보 =====
server:
  hostname: my-server
  timezone: Asia/Seoul

# ===== 패키지 =====
packages:
  apt:          # apt로 설치할 패키지
    - htop
    - curl
    - wget
    - git
    - vim
    - ufw
    - jq
    - tree
  snap:         # snap으로 설치할 패키지
    - name: docker
      classic: true
  pip:          # pip으로 설치할 패키지
    - requests

# ===== 서비스 =====
services:
  enable:       # 부팅 시 자동 활성화
    - nginx
    - docker
  start:        # 현재 바로 시작
    - nginx
    - docker

# ===== 방화벽 (UFW) =====
firewall:
  default_input: deny      # deny | allow
  default_output: allow
  rules:
    - port: 22/tcp
      action: allow
      comment: SSH
    - port: 80/tcp
      action: allow
      comment: HTTP
    - port: 443/tcp
      action: allow
      comment: HTTPS

# ===== 사용자 =====
users:
  - name: deploy
    shell: /bin/bash
    groups:
      - sudo
      - docker
    ssh_key: "ssh-rsa AAAA..."   # 공개키 (선택)
    password: ""                  # 비밀번호 (선택, 비우면 무작위 생성)

# ===== 디렉토리 =====
directories:
  - path: /opt/apps
    owner: deploy:deploy
    mode: "0755"
  - path: /var/www/html
    owner: www-data:www-data
    mode: "0755"

# ===== 커맨드 (설치 후 실행) =====
commands:
  - echo "Setup complete!"
  - docker --version
  - nginx -t

# ===== 설정 파일 (직접 쓰기) =====
files:
  - path: /etc/nginx/conf.d/app.conf
    content: |
      server {
          listen 80;
          server_name _;
          root /var/www/html;
      }
    owner: root:root
    mode: "0644"
```

---

## 카테고리별 추천 패키지

### 🛠️ 베이직 (모두 추천)
```yaml
packages:
  apt:
    - htop, curl, wget, git, vim, ufw, jq, tree, unzip, software-properties-common
```

### 🌐 웹서버
```yaml
packages:
  apt:
    - nginx, certbot, python3-certbot-nginx
services:
  enable: [nginx]
  start: [nginx]
firewall:
  rules:
    - { port: 80/tcp, action: allow, comment: HTTP }
    - { port: 443/tcp, action: allow, comment: HTTPS }
```

### 🐳 Docker 환경
```yaml
packages:
  apt:
    - docker.io, docker-compose
services:
  enable: [docker]
  start: [docker]
users:
  - name: deploy
    groups: [sudo, docker]
```

### 🗄️ 데이터베이스
```yaml
packages:
  apt:
    - mysql-server, redis-server
services:
  enable: [mysql, redis]
  start: [mysql, redis]
firewall:
  rules:
    - { port: 3306/tcp, action: allow, comment: MySQL }
    - { port: 6379/tcp, action: allow, comment: Redis }
```

### 📊 모니터링
```yaml
packages:
  apt:
    - netdata
  snap:
    - name: glances
services:
  enable: [netdata]
  start: [netdata]
firewall:
  rules:
    - { port: 19999/tcp, action: allow, comment: Netdata }
```

### 🔒 보안 강화
```yaml
packages:
  apt:
    - fail2ban, ufw
services:
  enable: [fail2ban]
  start: [fail2ban]
firewall:
  default_input: deny
  rules:
    - { port: 22/tcp, action: allow, comment: SSH }
```

---

## 예시 설정 파일

`config.example.yaml` 참조:
```yaml
server:
  hostname: my-ubuntu-server
  timezone: Asia/Seoul

packages:
  apt:
    - htop
    - curl
    - wget
    - git
    - vim
    - ufw
    - jq
    - tree
    - docker.io
    - nginx
    - fail2ban
  snap: []

services:
  enable:
    - docker
    - nginx
    - fail2ban
  start:
    - docker
    - nginx
    - fail2ban

firewall:
  default_input: deny
  default_output: allow
  rules:
    - port: 22/tcp
      action: allow
      comment: SSH
    - port: 80/tcp
      action: allow
      comment: HTTP
    - port: 443/tcp
      action: allow
      comment: HTTPS

users:
  - name: deploy
    shell: /bin/bash
    groups:
      - sudo
      - docker

directories:
  - path: /opt/apps
    owner: root:root
    mode: "0755"

commands:
  - echo "✅ Ubuntu Init Complete!"
  - docker --version
  - nginx -t

files: []
```

---

## 커뮤니티 YAML 공유

이 프로젝트의 재미 포인트! 설정 파일을 공유하면 다른 사람이 바로 사용할 수 있습니다.

### 공유 형식
```
📁 profiles/
├── webserver.yaml      # Nginx 웹서버
├── docker-homelab.yaml # Docker Homelab
├── dev-env.yaml        # 개발 환경
├── monitor.yaml        # 모니터링 서버
└── game-server.yaml    # 게임 서버
```

### YAML 작성 규칙
- 설명은 `comment` 필드 또는 상단에 주석으로
- 다른 사람도 바로 쓸 수 있도록 hostname/사용자명은 일반적으로
- 불필요한 패키지 포함 금지 (minimal이美)

---

## 주의사항

- ⚠️ **항상 sudo로 실행**해야 합니다
- ⚠️ UFW 설정 전 SSH 포트를 반드시 허용하세요 (접속 끊김 주의)
- ⚠️ 비밀번호는 로그에 출력되지 않도록 주의
- ⚠️ 테스트 먼저! VM이나 staging에서 검증 후 프로덕션 적용

---

## 프로젝트 구조

```
ubuntu-init/
├── AGENT.md              # 이 파일 (프로젝트 문서)
├── config.yaml           # 사용자 설정 (직접 편집)
├── config.example.yaml   # 예시 설정
├── setup.sh              # 메인 설치 스크립트
└── profiles/             # 커뮤니티 YAML 프로필 (추후)
```
