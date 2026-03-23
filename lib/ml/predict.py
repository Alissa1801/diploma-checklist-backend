import sys
import json
import os
import warnings
warnings.filterwarnings('ignore') # Убираем лишние предупреждения

from ultralytics import YOLO

def run_prediction(image_path, model_path):
    try:
        model = YOLO(model_path)
        # Указываем точный путь для сохранения
        project_path = "public/analysis"
        name = "predict"
        
        results = model.predict(
            source=image_path, 
            conf=0.3, 
            save=True, 
            project=project_path, 
            name=name, 
            exist_ok=True,
            verbose=False # КРИТИЧНО: чтобы в консоль шел только наш JSON
        )
        
        result = results[0]
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        # Твои классы из датасета
        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        
        # Получаем имя сохраненного файла (YOLO может его переименовать)
        # Обычно это public/analysis/predict/имя_файла.jpg
        output_filename = os.path.basename(result.path)
        processed_url = f"/analysis/predict/{output_filename}"

        output = {
            "is_approved": is_approved,
            "confidence": float(result.boxes.conf[0] * 100) if len(result.boxes.conf) > 0 else 0,
            "objects": [{"name": cls, "count": detected_classes.count(cls)} for cls in set(detected_classes)],
            "issues": found_issues,
            "feedback": "Check passed" if is_approved else "Issues detected",
            "processed_url": processed_url
        }
        # Печатаем ТОЛЬКО JSON
        sys.stdout.write(json.dumps(output))
        
    except Exception as e:
        sys.stdout.write(json.dumps({"error": str(e)}))

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])