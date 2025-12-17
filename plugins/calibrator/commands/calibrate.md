---
name: calibrate
description: LLM 기대 불일치 기록. 초기화되지 않은 경우 초기화 안내.
---

# /calibrate

Claude가 기대와 다르게 생성했을 때 패턴을 기록합니다.

## i18n 메시지 참조

모든 사용자 대면 메시지는 `plugins/calibrator/i18n/messages.json`을 참조합니다.
실행 시 `.claude/calibrator/config.json`의 `language` 필드를 읽어 해당 언어 메시지를 사용합니다.

```bash
# jq 사용으로 안정적인 JSON 파싱
LANG=$(jq -r '.language // "en"' .claude/calibrator/config.json 2>/dev/null)
LANG=${LANG:-en}  # 기본값: 영어
```

## 실행 전 확인

1. `.claude/calibrator/patterns.db` 존재 여부 확인:
   ```bash
   test -f .claude/calibrator/patterns.db
   ```

2. 파일이 없으면:
   - i18n 키: `calibrate.not_initialized` - 사용자에게 초기화 여부 질문
   - Y 선택 시: `/calibrate init` 실행 후 계속 진행
   - n 선택 시: i18n 키: `calibrate.run_init_first` 안내 후 종료

## 기록 플로우

### Step 1: 카테고리 선택
i18n 키 참조:
- `calibrate.category_prompt` - 질문
- `calibrate.category_missing` - 옵션 1
- `calibrate.category_excess` - 옵션 2
- `calibrate.category_style` - 옵션 3
- `calibrate.category_other` - 옵션 4

영어 예시:
```
What kind of mismatch just happened?

1. Something was missing
2. There was something unnecessary
3. I wanted a different approach
4. Let me explain
```

카테고리 매핑:
- 1 → `missing`
- 2 → `excess`
- 3 → `style`
- 4 → `other`

### Step 2: 상황과 기대 입력
i18n 키 참조:
- `calibrate.situation_prompt` - 질문
- `calibrate.situation_example` - 예시
- `calibrate.situation_label` - 상황 레이블
- `calibrate.expectation_label` - 기대 레이블

영어 예시:
```
In what situation, and what did you expect?
Example: "When creating a model, include timestamp field"

Situation: [user input]
Expected: [user input]
```

### Step 3: DB 기록

1. observations 테이블에 기록:
   ```bash
   sqlite3 .claude/calibrator/patterns.db "INSERT INTO observations (category, situation, expectation) VALUES ('$CATEGORY', '$SITUATION', '$EXPECTATION');"
   ```

2. patterns 테이블에서 동일 situation 검색:
   ```bash
   sqlite3 .claude/calibrator/patterns.db "SELECT id, count FROM patterns WHERE situation = '$SITUATION';"
   ```

   - 있으면: count +1, last_seen 업데이트
     ```bash
     sqlite3 .claude/calibrator/patterns.db "UPDATE patterns SET count = count + 1, last_seen = CURRENT_TIMESTAMP WHERE situation = '$SITUATION';"
     ```
   - 없으면: 새 패턴 생성, instruction은 기대를 DO 형태로 변환
     ```bash
     sqlite3 .claude/calibrator/patterns.db "INSERT INTO patterns (situation, instruction) VALUES ('$SITUATION', '$INSTRUCTION');"
     ```

   instruction 생성 규칙:
   - 기대(expectation)를 명령형으로 변환
   - 예: "timestamp 필드 포함" → "timestamp 필드를 항상 포함하세요"

### Step 4: 결과 출력
i18n 키 참조:
- `calibrate.record_complete` - 완료 타이틀
- `calibrate.situation_label` - 상황 레이블
- `calibrate.expectation_label` - 기대 레이블
- `calibrate.pattern_count` - 패턴 누적 횟수 (placeholder: {count})
- `calibrate.promotion_hint` - 승격 안내

영어 예시:
```
✅ Record complete

Situation: {situation}
Expected: {expectation}

Same pattern accumulated {count} times
```

count가 2 이상이면 추가:
```
💡 You can promote this to a Skill with /calibrate review.
```
