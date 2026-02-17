Using Flutter

1p(저장)
	1.	BridgeService가 assets/data.csv 읽어서 교량 목록 로드
	2.	사용자가 교량/방향/위치/내용 선택
	3.	Sanitizer가 파일명 생성: 교량-방향-위치-내용.jpg
	4.	ManifestService.savePhoto()가
	•	/storage/emulated/0/Pictures/ 에 파일 저장(덮어쓰기 방지)
	•	saved_photos.json에 메타 기록(atomic 저장)

2p (ZIP)
	1.	ManifestService.loadAll()로 저장 목록 로드
	2.	체크된 사진만 ZipService.buildZip()로 ZIP 생성
	•	ZIP 내부 구조: 교량/방향/위치/파일명.jpg
	3.	ZIP 저장 위치: /storage/emulated/0/Download/BridgeCameraApp/exports/
	4.	share_plus로 ZIP 공유 가능

error log
	•	앱 크래시/예외 발생 시 LoggerService가
	•	/storage/emulated/0/Download/BridgeCameraApp/logs/error_YYYYMMDD.log
	•	여기에 append로 기록
