# 🐧 Ubuntu Server Initializer

> 새 Ubuntu 서버를 YAML 설정 한 장으로 자동 세팅하는 도구

`config.yaml`에 원하는 패키지, 서비스, 사용자, 방화벽 설정을 작성하면 `setup.sh` 한 번 실행으로 모든 것을 자동 설치합니다.

---

## ✨ Features

- **YAML 기반 설정** — 모든 설치 내용을 하나의 YAML 파일로 관리
- **자동 업데이트** — 실행 전 `apt update/upgrade` 자동 수행
- **개발 환경 원스톱** — Go, Rust, Kotlin, Node.js, Deno, Bun, Anaconda, uv 등
- **서버 기본 설정** — 호스트명, 타임존, 사용자, 방화벽, 서비스 자동 구성
- **커뮤니티 공유** — YAML 파일을 공유하면 누구나 동일한 환경 구축

---

## 🚀 Quick Start

```bash
# 1. 복사
cp config.example.yaml config.yaml

# 2. 편집 (원하는 패키지/설정 작성)
vim config.yaml

# 3. 실행
sudo ./setup.sh
```

---

## 📋 설치 과정 (12단계)

```
 0/12 시스템 업데이트      apt update + upgrade
 1/12 호스트명 설정
 2/12 타임존 설정
 3/12 APT 패키지 설치      curl, git, golang, zsh 등
 4/12 SNAP 패키지 설치
 5/12 PIP 패키지 설치
 6/12 서비스 설정           enable / start
 7/12 방화벽 설정           UFW 규칙 자동 구성
 8/12 사용자 생성           그룹, SSH 키, 비밀번호
 9/12 디렉토리 생성
10/12 설정 파일 작성        nginx, 앱 설정 등 직접 작성
11/12 후처리 커맨드 실행    Rust, nvm, Bun, Deno, Anaconda, uv, oh-my-zsh
```

---

## 📝 YAML 설정 스펙

```yaml
server:
  hostname: my-server
  timezone: Asia/Seoul

packages:
  apt:                          # apt 패키지
    - curl
    - wget
    - git
    - golang
    - zsh
  snap:                         # snap 패키지
    - name: docker
      classic: true
  pip:                          # pip 패키지
    - requests

services:
  enable:                       # 부팅 시 자동 활성화
    - docker
  start:                        # 즉시 시작
    - docker

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

users:
  - name: deploy
    shell: /bin/bash
    groups: [sudo, docker]
    ssh_key: "ssh-rsa AAAA..."
    password: ""

directories:
  - path: /opt/apps
    owner: deploy:deploy
    mode: "0755"

commands:                       # 모든 설치 후 실행
  - curl -fsSL https://sh.rustup.rs | sh -s -- -y
  - 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'

files:                          # 설정 파일 직접 작성
  - path: /etc/nginx/conf.d/app.conf
    content: |
      server { listen 80; root /var/www/html; }
    owner: root:root
    mode: "0644"
```

---

## 📦 추천 구성

### 개발 서버

```yaml
packages:
  apt:
    - curl, wget, git, unzip, zsh, golang

commands:
  - 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
  - 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'
  - 'curl -fsSL https://deno.land/install.sh | sh'
  - 'curl -fsSL https://bun.com/install | bash'
  - 'curl -LsSf https://astral.sh/uv/install.sh | sh'
```

### 웹 서버

```yaml
packages:
  apt:
    - nginx, certbot, python3-certbot-nginx, fail2ban

services:
  enable: [nginx, fail2ban]
  start: [nginx, fail2ban]

firewall:
  rules:
    - { port: 80/tcp, action: allow }
    - { port: 443/tcp, action: allow }
```

---

## ⚠️ 주의사항

- **항상 sudo로 실행**: `sudo ./setup.sh`
- **SSH 포트 반드시 허용**: UFW 설정 시 접속 끊김 방지
- **테스트 필수**: VM이나 staging에서 먼저 검증 후 프로덕션 적용
- **Anaconda 설치 시**: PATH 반영을 위해 `source ~/.bashrc` 또는 재로그인 필요

---

## 📂 프로젝트 구조

```
ubuntu-init/
├── README.md             # 이 파일
├── AGENT.md              # 상세 문서
├── config.yaml           # 사용자 설정 (편집)
├── config.example.yaml   # 예시 설정
└── setup.sh              # 메인 설치 스크립트
```

---

## 📄 License

MIT
