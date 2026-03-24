import sys
import json
import os
import warnings
# Устанавливаем кодировку вывода, чтобы кириллица (если будет) не ломала Ruby
sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

from ultralytics import YOLO

def run_prediction(image_path, model_path):
    try:
        model = YOLO(model_path)
        
        # Используем абсолютный путь, чтобы Python точно знал, где корень
        base_path = os.getcwd() 
        project_path = os.path.join(base_path, "public", "analysis")
        
        results = model.predict(
            source=image_path, 
            conf=0.25, # Немного снизим порог для более точного поиска мусора
            save=True, 
            project=project_path, 
            name="predict", 
            exist_ok=True,
            verbose=False 
        )
        
        result = results[0]
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        # Твои классы
        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        
        # Получаем имя файла. YOLO сохраняет его в project/name/filename
        # Нам нужно только имя файла для URL
        output_filename = os.path.basename(result.path)

        output = {
            "is_approved": is_approved,
            "confidence": float(result.boxes.conf.mean() * 100) if len(result.boxes.conf) > 0 else 100.0,
            "objects": [{"name": cls, "count": detected_classes.count(cls)} for cls in set(detected_classes)],
            "issues": found_issues,
            "feedback": "Cleanliness standards met" if is_approved else f"Issues found: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        # Выводим финальный JSON
        print(json.dumps(output, ensure_ascii=False))
        
    except Exception as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])