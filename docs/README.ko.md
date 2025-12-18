# Skillfy

🌍 [English](../README.md) | **한국어** | [日本語](./README.ja.md) | [中文](./README.zh.md)

![macOS: 지원](https://img.shields.io/badge/macOS-지원-brightgreen?style=for-the-badge&logo=apple&logoColor=white)
![Linux: 지원](https://img.shields.io/badge/Linux-지원-brightgreen?style=for-the-badge&logo=linux&logoColor=white)
![Windows: WSL 사용](https://img.shields.io/badge/Windows-WSL%20사용-blue?style=for-the-badge&logo=windows&logoColor=white)

> **Windows 사용자**: [WSL (Windows Subsystem for Linux)](https://learn.microsoft.com/ko-kr/windows/wsl/install)을 통해 Skillfy를 실행하세요.

여러분의 피드백을 재사용 가능한 Claude Code 스킬(Skill)로 만들어보세요.

Claude Code 플러그인으로, 피드백을 지속적인 학습으로 전환합니다.

## 핵심 개념

```
Claude의 응답이 기대와 다를 때
       ↓
/skillfy로 기록
       ↓
/skillfy review로 스킬(Skill)로 승격
       ↓
이후 Claude가 자동으로 해당 규칙을 적용
```

## 설치

먼저 플러그인을 로컬 마켓플레이스에 추가한 후 설치하세요:
```bash
/plugin marketplace add https://github.com/yhzion/claude-code-skillfy.git
/plugin install skillfy@claude-code-skillfy
```

### 업데이트

```bash
/plugin marketplace update claude-code-skillfy
```

### 제거

플러그인을 완전히 제거하려면 먼저 플러그인을 제거한 후 마켓플레이스에서 삭제하세요:
```bash
/plugin uninstall skillfy@claude-code-skillfy
/plugin marketplace remove claude-code-skillfy
```

## 사용법

### 초기화

```bash
/skillfy init
```

Skillfy 데이터베이스와 디렉토리 구조를 생성합니다.

> **참고**: Skillfy는 Git 저장소 루트에 설치됩니다. Git 저장소가 아닌 경우 현재 디렉토리에 설치됩니다.

<details>
<summary>📖 자세한 사용법</summary>

**생성되는 항목:**
- `.claude/skillfy/patterns.db` - SQLite 데이터베이스
- `.claude/skills/` - 승격된 스킬(Skill) 저장 디렉토리
- `.gitignore`에 항목 추가 (Git 프로젝트인 경우)

**흐름:**

1. **확인:**
   - "Skillfy를 초기화하시겠습니까?" → [예, 초기화] [취소]

2. **이미 존재하는 경우:**
   - "Skillfy가 이미 존재합니다" → [유지] [재초기화 (데이터 삭제)]
   - 참고: 스키마 업그레이드는 재초기화로 처리됩니다. 인플레이스 마이그레이션은 없으니 필요시 데이터를 백업하세요.

3. **완료:**
   ```
   Skillfy 초기화 완료

   - .claude/skillfy/patterns.db 생성됨
   - .claude/skills/ 디렉토리 생성됨
   - .gitignore 업데이트됨 (Git 프로젝트인 경우)

   이제 /skillfy로 불일치 항목을 기록할 수 있습니다.
   /skillfy review로 저장된 패턴을 스킬로 승격하세요.
   ```

</details>

---

### 불일치 기록

```bash
/skillfy
```

Claude가 기대와 다른 결과를 생성했을 때 패턴을 기록합니다.

<details>
<summary>📖 자세한 사용법</summary>

> **스마트 제안**: Claude가 현재 세션 컨텍스트를 분석하여 각 단계에서 관련 옵션을 동적으로 제안합니다. 제안이 맞지 않으면 "직접 입력"을 선택할 수 있습니다.

**1단계: 상황 선택** (최대 500자)

Claude가 현재 세션을 분석하여 관련 상황을 제안합니다:
```
패턴 불일치 기록

어떤 상황에서 발생했나요?

1. {컨텍스트 분석 기반 제안 상황}
2. {최근 오류/수정 기반 다른 제안}
3. 직접 입력

선택:
```

**2단계: 기대 선택** (최대 1000자)

선택한 상황에 기반하여 Claude가 기대사항을 제안합니다:
```
무엇을 기대했나요?

1. {상황 기반 제안 기대사항}
2. {또 다른 관련 기대사항}
3. 직접 입력

선택:
```

**3단계: 지시사항 선택** (최대 2000자)

Claude가 실행 가능한 지시사항을 제안합니다:
```
Claude가 어떤 규칙을 학습해야 하나요? (명령형)

1. {제안 지시사항 - 예: "항상 타임스탬프 필드 포함"}
2. {다른 지시사항 옵션}
3. 직접 입력

선택:
```

**4단계: 액션 선택**
```
기록 요약

상황: {상황}
기대: {기대사항}
지시사항: {지시사항}

어떻게 하시겠습니까?

1. 스킬로 등록 - 즉시 스킬 파일 생성
2. 메모로 저장 - 나중에 검토하기 위해 DB에 저장
3. 취소

선택:
```

</details>

---

### 검토 및 스킬로 승격

```bash
/skillfy review
```

저장된 패턴을 검토하고 스킬(Skill)로 승격합니다.

<details>
<summary>📖 자세한 사용법</summary>

**1단계: 저장된 패턴 보기**
```
저장된 패턴 (아직 승격되지 않음)

[id=12] 모델 생성 시 → 항상 타임스탬프 필드 포함 (2024-12-18)
[id=15] API 엔드포인트 작성 시 → 항상 에러 처리 포함 (2024-12-17)

승격할 패턴 id를 입력하세요 (쉼표로 구분하여 여러 개 선택 가능, 취소하려면 'skip' 입력):
예: 12 또는 12,15
```

**2단계: 스킬 미리보기**
```
스킬 미리보기: {상황}

---
name: {케밥케이스 상황}
description: {지시사항}. {상황} 상황에서 자동 적용됨.
learned_from: skillfy ({생성일})
---

## 규칙

{지시사항}

## 적용 대상

- {상황}

## 예시

### 올바른 예

(여기에 긍정적 예시 추가)

### 잘못된 예

(여기에 부정적 예시 추가)

## 학습 이력

- 생성일: {생성일}
- 출처: /skillfy를 통한 수동 기록

---

[저장] [편집] [건너뛰기]
```

**3단계: 결과**
```
✅ 스킬 생성됨

- .claude/skills/{스킬명}/SKILL.md

🔄 이 스킬을 활성화하려면 Claude Code를 재시작하세요.
```

</details>

---

### 도움말 보기

```bash
/skillfy help
```

사용 가능한 명령어와 현재 상태를 표시합니다.

<details>
<summary>📖 자세한 사용법</summary>

**출력 (초기화된 경우):**
```
📚 Skillfy 도움말

상태: ✅ 초기화됨 | 패턴: {개수} | 스킬: {개수} | 대기 중: {개수}

명령어:
  /skillfy init      Skillfy 초기화
  /skillfy           기대 불일치 기록
  /skillfy review    패턴을 스킬로 승격
  /skillfy reset     모든 데이터 삭제
  /skillfy help      이 도움말 표시

빠른 시작:
  1. /skillfy init → 2. /skillfy → 3. /skillfy review
```

</details>

---

### 데이터 초기화

```bash
/skillfy reset
```

⚠️ 모든 패턴 기록을 삭제합니다. 생성된 스킬은 유지됩니다.

<details>
<summary>📖 자세한 사용법</summary>

**옵션:**
- `/skillfy reset` - 데이터베이스 기록만 삭제 (스킬 유지)
- `/skillfy reset --all` - 스킬을 포함한 모든 것 삭제
  > ⚠️ **주의**: 이 옵션은 Skillfy가 아닌 스킬을 포함하여 `.claude/skills/` 디렉토리 전체를 삭제합니다. 이 옵션을 사용하기 전에 중요한 스킬을 백업하세요.

**1단계: 현재 상태**
```
⚠️ Skillfy 초기화

데이터베이스 파일:
- {DB_PATH}

삭제될 데이터:
- {개수}개의 패턴

참고: 생성된 스킬(.claude/skills/)은 유지됩니다.
```

**2단계: 확인**
- "모든 Skillfy 데이터를 삭제하시겠습니까?"
- [예, 모든 데이터 초기화] [취소]

**3단계: 결과**
```
✅ Skillfy 데이터가 초기화되었습니다

- 패턴: 모두 삭제됨
- 스킬: 유지됨 (.claude/skills/)

/skillfy로 새 기록을 시작하세요.
```

</details>

## 예시

Skillfy 사용법을 익히기 위한 두 가지 일반적인 시나리오입니다.

### 예시 1: 코드 스타일 선호도

처음부터 끝까지 실제 시나리오를 살펴보겠습니다.

#### 😤 문제 상황

Claude에게 React 컴포넌트 생성을 요청합니다:

```
> Button 컴포넌트 만들어줘
```

Claude의 응답:
```jsx
const Button = ({ label, onClick }) => {
  return <button onClick={onClick}>{label}</button>
}
```

**원했던 건 TypeScript 인터페이스인데!** 이런 일이 계속 반복됩니다...

---

#### 📝 1단계: 불일치 기록

불일치가 발생한 직후 `/skillfy` 실행:

```
상황: > React 컴포넌트 생성 시
기대: > props에 대한 TypeScript 인터페이스
지시사항: > 컴포넌트 props에 대해 항상 TypeScript 인터페이스 정의

어떻게 하시겠습니까?
> 1. 스킬로 등록
```

결과:
```
✅ 스킬 생성됨: .claude/skills/creating-react-components/SKILL.md

🔄 이 스킬을 활성화하려면 Claude Code를 재시작하세요.
```

---

#### ✨ 2단계: 결과

**Claude Code 재시작** 후 같은 질문:

```
> Button 컴포넌트 만들어줘
```

이제 Claude의 응답:
```tsx
interface ButtonProps {
  label: string;
  onClick: () => void;
}

const Button = ({ label, onClick }: ButtonProps) => {
  return <button onClick={onClick}>{label}</button>
}
```

🎉 **Claude가 여러분의 선호도를 학습하여 자동으로 적용합니다!**

---

### 예시 2: 워크플로우 동작 선호도

Claude가 자동으로 처리할지 확인을 요청할지 가르치는 방법을 알아봅니다.

#### 😤 문제 상황

Claude에게 코드 품질 검사를 요청합니다:

```
> 린트하고 포맷 확인해줘
```

Claude가 문제를 발견하고 물어봅니다:
```
발견된 문제:

| 검사     | 상태                           |
|----------|--------------------------------|
| ESLint   | ⚠️ 경고 1개                    |
| Prettier | ❌ 포맷팅 필요 파일 2개        |

이 문제들을 수정할까요?
```

**그냥 수정해주면 되는데!** 매번 물어보지 않았으면...

---

#### 📝 1단계: 불일치 기록

불일치가 발생한 직후 `/skillfy` 실행:

```
상황: > 린트/포맷 확인 시
기대: > 묻지 않고 자동 수정, 수정 후 보고
지시사항: > 묻지 않고 수정, 수정 후 보고

어떻게 하시겠습니까?
> 1. 스킬로 등록
```

결과:
```
✅ 스킬 생성됨: .claude/skills/when-checking-lintformat/SKILL.md

🔄 이 스킬을 활성화하려면 Claude Code를 재시작하세요.
```

---

#### ✨ 2단계: 결과

**Claude Code 재시작** 후 같은 질문:

```
> 린트하고 포맷 확인해줘
```

이제 Claude의 응답:
```
스킬에서 묻지 않고 수정하라고 지시합니다. 지금 문제를 수정하겠습니다.

✅ 모든 문제 수정됨:

| 검사     | 결과                                           |
|----------|------------------------------------------------|
| Prettier | ✅ 2개 파일 포맷팅됨 (App.vue, HelloWorld.vue) |
| ESLint   | ✅ 에러 0개, 경고 0개                          |

변경 사항:
- src/App.vue — 포맷팅 수정됨
- src/components/HelloWorld.vue — 포맷팅 수정됨 + 기본값 추가됨
```

🎉 **Claude가 여러분의 워크플로우 선호도를 학습하여 묻지 않고 처리합니다!**

---

#### ⚠️ 참고: 스킬 활성화

스킬이 항상 자동으로 트리거되지 않을 수 있습니다. Claude가 스킬을 적용하지 않는 경우:

1. **설명 개선** - 스킬의 `description` 필드를 더 구체적으로 작성
2. **수동 호출** - 명시적으로 호출할 수 있습니다:
   ```
   > 린트하고 포맷 확인해줘. 스킬: when-checking-lintformat 사용
   ```
3. **스킬 로딩 확인** - `/skillfy help`를 실행하여 스킬이 인식되는지 확인

---

## 모범 사례

권장 워크플로우:

```
1. Claude와 평소처럼 작업
       ↓
2. 불일치 발견? 즉시 /skillfy 실행
       ↓
3. 구체적으로: "코딩할 때" < "React 컴포넌트 생성 시"
       ↓
4. 명확한 지시사항 작성: "항상 TypeScript 인터페이스 사용"
       ↓
5. 새 스킬 활성화를 위해 Claude Code 재시작
```

**팁:**
- 📝 불일치가 **발생한 직후** 기록하세요 - 컨텍스트가 중요합니다
- 🎯 상황을 **구체적으로** - 모호한 패턴은 도움이 되지 않습니다
- ✍️ **명령형 지시사항** 작성 - "항상 X 하기" 또는 "절대 Y 하지 않기"
- 🚀 스킬 생성 후 **Claude Code 재시작**하여 로드하세요

## 작동 방식

1. **기록**: `/skillfy`로 Claude의 출력이 기대와 다른 상황을 기록
2. **저장 또는 승격**: 나중을 위해 메모로 저장하거나 즉시 스킬 생성
3. **검토**: `/skillfy review`로 저장된 패턴을 스킬로 승격
4. **적용**: 스킬로 승격되면 Claude가 유사한 상황에서 자동 적용

## 데이터 저장

| 파일 | 용도 |
|------|------|
| `.claude/skillfy/patterns.db` | SQLite DB (`patterns`, `schema_version` 테이블) |
| `.claude/skills/*/SKILL.md` | 승격된 스킬 |

### 스킬 명명 규칙

스킬 생성 시 이름은 상황에서 자동 생성됩니다:

| 규칙 | 예시 |
|------|------|
| 소문자로 변환 | "Creating Models" → "creating-models" |
| 공백을 하이픈으로 대체 | "API endpoint" → "api-endpoint" |
| 특수문자 제거 | "React (TSX)" → "react-tsx" |
| 최대 50자 | 초과 시 잘림 |
| 충돌 처리 | 접미사 추가: `-1`, `-2` 등 |

## 보안 고려사항

### 데이터 개인정보

- **patterns.db에는 민감한 데이터가 포함될 수 있습니다**: 데이터베이스는 기록한 상황과 기대사항을 저장합니다. 포함하는 정보에 주의하세요.
- **자동 .gitignore**: init 명령은 실수로 커밋하는 것을 방지하기 위해 자동으로 `.claude/skillfy/`를 `.gitignore`에 추가합니다.
- **커밋 전 스킬 파일 검토**: `.claude/skills/`의 생성된 스킬은 gitignore에 포함되지 않습니다. 버전 관리에 커밋하기 전에 민감한 컨텍스트가 있는지 검토하세요.
- **백업 제외**: 민감한 정보가 포함된 경우 클라우드 동기화 서비스에서 `.claude/skillfy/`를 제외하는 것을 고려하세요.

### 파일 권한

초기화 중 보안 권한이 **자동으로 설정**됩니다:

| 경로 | 권한 | 설명 |
|------|------|------|
| `.claude/skillfy/` | `700` (rwx------) | 소유자만: 읽기, 쓰기, 실행 |
| `.claude/skills/` | `700` (rwx------) | 소유자만: 읽기, 쓰기, 실행 |
| `patterns.db` | `600` (rw-------) | 소유자만: 읽기, 쓰기 |

### 입력 검증
- SQL 인젝션은 따옴표 이스케이프로 방지됩니다
- 경로 탐색은 스킬 이름 생성에서 방지됩니다

## 문제 해결

### 일반적인 문제

**"sqlite3가 필요하지만 설치되어 있지 않습니다"**
- macOS/Linux: sqlite3는 일반적으로 사전 설치되어 있습니다
- Windows: https://sqlite.org/download.html 에서 설치

**스킬이 적용되지 않음**
- 스킬이 제대로 생성되었는지 확인 (`/skillfy help`로 상태 확인)
- `.claude/skills/`에 스킬 파일이 있는지 확인
- 새 스킬을 로드하려면 **Claude Code 재시작**

## 요구 사항

- Claude Code
- sqlite3 CLI (macOS/Linux에 사전 설치됨)
- SQLite 버전 3.24.0 이상 (향상된 성능 및 호환성)
- `realpath` 또는 `python3` (review 명령의 경로 확인용; 일반적으로 사전 설치됨)

## 라이선스

MIT
