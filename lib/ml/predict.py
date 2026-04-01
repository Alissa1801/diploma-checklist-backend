import sys
import os
import json
import warnings
import shutil

# --- ФИНАЛЬНЫЙ ФИКС ПУТЕЙ ---
# Мы принудительно ставим нашу папку с библиотеками на первое место в списке поиска
lib_path = "/opt/python_libs"
if os.path.exists(lib_path):
    sys.path.insert(0, lib_path)

# Добавляем стандартные пути на случай, если что-то осталось там
for path in ["/usr/local/lib/python3.11/dist-packages", "/usr/lib/python3/dist-packages"]:
    if os.path.exists(path) and path not in sys.path:
        sys.path.append(path)

try:
    import numpy as np
    # Исправляем возможный конфликт типов NumPy 2.0 (актуально для последних сборок)
    np.ndarray = type(np.array([]))
    
    from ultralytics import YOLO
except ImportError as e:
    # Если импорт не удался, выводим подробный лог для отладки в Railway
    print(json.dumps({
        "error": f"Python Dependency Error: {str(e)}",
        "debug_info": {
            "sys_path": sys.path,
            "lib_path_exists": os.path.exists(lib_path)
        }
    }))
    sys.exit(1)

# Настройка вывода для захвата данных сервисом Ruby (UTF-8)
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

def run_prediction(image_path, model_path):
    # 1. Проверка существования файлов
    if not os.path.exists(image_path):
        print(json.dumps({"error": f"Image not found at {image_path}"}))
        return
    if not os.path.exists(model_path):
        print(json.dumps({"error": f"Model not found at {model_path}"}))
        return

    try:
        # 2. Загрузка модели
        model = YOLO(model_path)
        
        # 3. Настройка путей сохранения (в Docker корень — /rails)
        project_path = "/rails/public/analysis"
        if not os.path.exists(project_path):
            os.makedirs(project_path, exist_ok=True)
            
        # 4. Анализ
        results = model.predict(
            source=image_path, 
            conf=0.25, 
            save=True, 
            project=project_path, 
            name="predict", 
            exist_ok=True,
            verbose=False 
        )
        
        if not results or len(results) == 0:
            print(json.dumps({"error": "YOLO returned no results"}))
            return

        result = results[0]
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        # Средняя уверенность по всем найденным объектам
        conf_value = 0.0
        if len(result.boxes.conf) > 0:
            conf_value = float(result.boxes.conf.mean().item()) * 100

        # Специфичные классы для отеля (на основе твоей модели)
        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        output_filename = os.path.basename(result.path)

        # 5. Формирование ответа
        output = {
            "is_approved": is_approved,
            "confidence": round(conf_value, 2),
            "objects": [{"name": str(cls), "count": int(detected_classes.count(cls))} for cls in set(detected_classes)],
            "issues": list(set(found_issues)),
            "feedback": "Стандарты соблюдены" if is_approved else f"Нарушения: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        print(json.dumps(output, ensure_ascii=False))
        sys.stdout.flush()
        
    except Exception as e:
        print(json.dumps({"error": f"Runtime error during prediction: {str(e)}"}))
        sys.stdout.flush()

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])
    else:
        print(json.dumps({"error": "Missing arguments. Usage: predict.py <img_path> <model_path>"}))