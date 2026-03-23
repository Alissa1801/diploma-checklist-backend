import sys
import json
import os
from ultralytics import YOLO

def run_prediction(image_path, model_path):
    try:
        model = YOLO(model_path)
        # Запускаем детекцию
        results = model.predict(source=image_path, conf=0.3, save=True, project="public/analysis", name="predict", exist_ok=True)
        
        # Получаем данные о найденных объектах
        result = results[0]
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        # Логика одобрения для диплома
        # Если находим 'pillow_messy' или 'trash' — отклоняем
        bad_stuff = ['pillow_messy', 'trash'] # замени на свои классы из датасета
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        
        # Путь к картинке с рамками (сохраняем в public, чтобы iOS видела по ссылке)
        output_filename = os.path.basename(image_path)
        processed_url = f"/analysis/predict/{output_filename}"

        output = {
            "is_approved": is_approved,
            "confidence": float(result.boxes.conf[0] * 100) if len(result.boxes.conf) > 0 else 0,
            "objects": [{"name": cls, "count": detected_classes.count(cls)} for cls in set(detected_classes)],
            "issues": found_issues,
            "feedback": "Check passed" if is_approved else "Issues detected",
            "processed_url": processed_url
        }
        print(json.dumps(output))
    except Exception as e:
        print(json.dumps({"error": str(e)}))

if __name__ == "__main__":
    run_prediction(sys.argv[1], sys.argv[2])