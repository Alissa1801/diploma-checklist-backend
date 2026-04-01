import sys
import os
import json
import warnings
import shutil

# --- ФИКС ПУТЕЙ: Заставляем Python видеть установленные пакеты ---
import site
# Добавляем все стандартные пути dist-packages
for path in ["/usr/local/lib/python3.11/dist-packages", "/usr/lib/python3/dist-packages"]:
    if os.path.exists(path) and path not in sys.path:
        sys.path.append(path)

try:
    import numpy as np
    # Исправляем возможный конфликт типов NumPy 2.0
    np.ndarray = type(np.array([]))
    from ultralytics import YOLO
except ImportError as e:
    print(json.dumps({"error": f"Python Dependency Error: {str(e)}. Path: {sys.path}"}))
    sys.exit(1)

# Отключаем лишние логи
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

def run_prediction(image_path, model_path):
    if not os.path.exists(image_path) or not os.path.exists(model_path):
        print(json.dumps({"error": "File not found"}))
        return

    try:
        model = YOLO(model_path)
        # Путь сохранения результатов в Rails
        project_path = "/rails/public/analysis"
        
        results = model.predict(
            source=image_path, 
            conf=0.25, 
            save=True, 
            project=project_path, 
            name="predict", 
            exist_ok=True,
            verbose=False 
        )
        
        if not results:
            print(json.dumps({"error": "No results"}))
            return

        result = results[0]
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        conf_value = float(result.boxes.conf.mean().item()) * 100 if len(result.boxes.conf) > 0 else 0

        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        output_filename = os.path.basename(result.path)

        output = {
            "is_approved": is_approved,
            "confidence": round(conf_value, 2),
            "objects": [{"name": str(cls), "count": int(detected_classes.count(cls))} for cls in set(detected_classes)],
            "issues": list(set(found_issues)),
            "feedback": "Ок" if is_approved else f"Проблемы: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        print(json.dumps(output, ensure_ascii=False))
        
    except Exception as e:
        print(json.dumps({"error": f"Runtime error: {str(e)}"}))

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])