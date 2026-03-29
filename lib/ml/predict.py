import sys
import json
import os
import warnings
import shutil

# 1. Срочное исправление конфликта типов Numpy и Ultralytics
try:
    import numpy as np
    # Если Numpy версии 1.24+ иногда капризничает с типами ndarray
    if not hasattr(np, "ndarray"):
        np.ndarray = np.array
except ImportError:
    print(json.dumps({"error": "Numpy not installed on server"}))
    sys.exit(1)

# Настройка кодировки для Ruby
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

from ultralytics import YOLO

def run_prediction(image_path, model_path):
    try:
        # 1. Загрузка модели
        model = YOLO(model_path)
        
        # 2. Настройка путей (относительно этого скрипта)
        base_path = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        project_path = os.path.join(base_path, "public", "analysis")
        
        if not os.path.exists(project_path):
            os.makedirs(project_path, exist_ok=True)
            
        save_dir = os.path.join(project_path, "predict")
        if os.path.exists(save_dir):
            shutil.rmtree(save_dir)
        
        # 3. Запуск предсказания
        results = model.predict(
            source=image_path, 
            conf=0.25, 
            save=True, 
            project=project_path, 
            name="predict", 
            exist_ok=True,
            verbose=False 
        )
        
        result = results[0]
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        # Классы проблем для логики отеля
        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        output_filename = os.path.basename(result.path)

        # 4. Формируем JSON
        output = {
            "is_approved": is_approved,
            "confidence": float(result.boxes.conf.mean() * 100) if len(result.boxes.conf) > 0 else 100.0,
            "objects": [{"name": cls, "count": detected_classes.count(cls)} for cls in set(detected_classes)],
            "issues": list(set(found_issues)),
            "feedback": "Стандарты чистоты соблюдены" if is_approved else f"Обнаружены проблемы: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        # 5. Вывод для Ruby
        print(json.dumps(output, ensure_ascii=False))
        sys.stdout.flush()
        
    except Exception as e:
        error_output = {"error": str(e)}
        print(json.dumps(error_output, ensure_ascii=False))
        sys.stdout.flush()

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])