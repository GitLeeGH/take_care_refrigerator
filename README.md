# 냉장고를 부탁해 (Take Care Refrigerator)

똑똑한 식재료 관리와 레시피 추천으로 당신의 주방 생활을 업그레이드하세요. "냉장고를 부탁해"는 냉장고 속 식재료를 효율적으로 관리하고, 유통기한을 추적하며, 보유한 재료를 바탕으로 멋진 레시피를 제안하는 스마트한 냉장고 관리 앱입니다.

## ✨ 주요 기능

- **식재료 관리**: 냉장고에 있는 식재료를 손쉽게 추가, 수정, 삭제하고 수량을 관리합니다.
- **유통기한 추적**: 식재료별 유통기한을 설정하고, 기한이 임박하면 알림을 받아 낭비를 줄일 수 있습니다.
- **스마트 레시피 추천**: 현재 보유한 식재료를 기반으로 만들 수 있는 다양한 레시피를 추천받으세요.
- **간편 로그인**: Google 계정 또는 익명 로그인을 통해 간편하게 앱을 시작할 수 있습니다.
- **사용자 맞춤 설정**: 자주 사용하는 식재료 목록, 알림 설정 등 사용자 편의에 맞게 앱을 설정할 수 있습니다.

## 🛠️ 사용된 기술

- **Frontend**: Flutter
- **Backend & DB**: Supabase (Authentication, Realtime Database, Storage)
- **State Management**: Riverpod
- **Authentication**: Google Sign-In, Supabase Auth
- **Notifications**: flutter_local_notifications

## 🚀 시작하기

이 프로젝트를 로컬 환경에서 실행하려면 아래 단계를 따라주세요.

### 사전 요구사항

- Flutter SDK가 설치되어 있어야 합니다.
- Supabase 계정과 프로젝트가 필요합니다.
- Google Cloud Platform에서 OAuth 클라이언트 ID가 필요합니다.

### 설치 및 실행

1.  **GitHub 저장소 복제(Clone):**
    ```sh
    git clone https://github.com/GitLeeGH/take_care_refrigerator.git
    cd take_care_refrigerator
    ```

2.  **Flutter 패키지 설치:**
    ```sh
    flutter pub get
    ```

3.  **.env 파일 설정:**
    프로젝트의 루트 디렉토리에 `.env` 파일을 생성하고 아래 내용을 자신의 Supabase 및 Google Client ID로 채워주세요.

    ```
    SUPABASE_URL=https://<YOUR_SUPABASE_PROJECT_ID>.supabase.co
    SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>
    GOOGLE_WEB_CLIENT_ID=<YOUR_GOOGLE_WEB_CLIENT_ID>
    ```

4.  **앱 실행 (웹):**
    웹에서 테스트할 경우, Supabase 및 Google Cloud Console에 설정한 포트 번호로 실행해야 합니다. (예: 50050)
    ```sh
    flutter run -d chrome --web-port=50050
    ```

5.  **앱 실행 (모바일):**
    ```sh
    flutter run
    ```

## 📸 스크린샷

(여기에 앱의 주요 화면 스크린샷을 추가할 수 있습니다.)

| 로그인 | 메인 화면 | 레시피 추천 |
| :---: | :---: | :---: |
| ![로그인](https://via.placeholder.com/300x600.png?text=Login+Screen) | ![메인](https://via.placeholder.com/300x600.png?text=Main+Screen) | ![레시피](https://via.placeholder.com/300x600.png?text=Recipe+Screen) |