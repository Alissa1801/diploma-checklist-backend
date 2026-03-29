import sys
import os
import json
import warnings
import shutil

# --- ТОТАЛЬНЫЙ ФИКС ПРОСТРАНСТВА ИМЕН И ТИПОВ ---
try:
    import numpy as np
    # Исправляет ошибку "expected np.ndarray (got numpy.ndarray)"
    sys.modules['np'] = np 
    if not hasattr(np, "ndarray"):
        np.ndarray = np.array
    if not hasattr(np, "float_"):
        np.float_ = np.float64
    # Для новых версий Numpy регистрируем старый интерфейс в системе
    if hasattr(np, "core"):
        sys.modules['numpy.core.multiarray'] = np.core.multiarray
except ImportError:
    print(json.dumps({"error": "Numpy failure"}))
    sys.exit(1)

# Настройка вывода для Ruby
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

from ultralytics import YOLO

def run_prediction(image_path, model_path):
    try:
        # 1. Загрузка модели
        model = YOLO(model_path)
        
        # 2. Настройка путей
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
        
        # Расчет уверенности (извлекаем чистый float из тензора)
        conf_value = 0.0
        if len(result.boxes.conf) > 0:
            conf_value = float(result.boxes.conf.mean().item()) * 100

        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        output_filename = os.path.basename(result.path)

        # 4. Формируем JSON (строгие типы данных)
        output = {
            "is_approved": is_approved,
            "confidence": round(conf_value, 2),
            "objects": [{"name": str(cls), "count": int(detected_classes.count(cls))} for cls in set(detected_classes)],
            "issues": list(set(found_issues)),
            "feedback": "Стандарты чистоты соблюдены" if is_approved else f"Обнаружены проблемы: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        print(json.dumps(output, ensure_ascii=False))
        sys.stdout.flush()
        
    except Exception as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        sys.stdout.flush()

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])