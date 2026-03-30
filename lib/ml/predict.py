import sys
import os
import json
import warnings
import shutil

# --- УЛЬТИМАТИВНЫЙ ЯДЕРНЫЙ ФИКС NUMPY 2.0 (ФИНАЛЬНАЯ ВЕРСИЯ) ---
try:
    import numpy as np
    
    # 1. РЕШЕНИЕ ОШИБКИ: expected np.ndarray (got numpy.ndarray)
    # Принудительно сопоставляем базовый класс массива
    actual_ndarray_type = type(np.array([]))
    np.ndarray = actual_ndarray_type
    
    # 2. Регистрация фикса в системных модулях Python для OpenCV
    sys.modules['np'] = np
    
    # 3. Эмуляция отсутствующих атрибутов для OpenCV (AttributeError)
    if not hasattr(np, '_globals'):
        class MockGlobals:
            _signature_descriptor = None
        np._globals = MockGlobals()
    
    # 4. Фикс для старых C-расширений (ImportError: multiarray)
    if hasattr(np, "core"):
        sys.modules['numpy.core.multiarray'] = np.core.multiarray
    
    # 5. Восстановление удаленных в 2.0 алиасов типов
    if not hasattr(np, "float_"): np.float_ = np.float64
    if not hasattr(np, "int_"): np.int_ = np.int64
    if not hasattr(np, "bool_"): np.bool_ = np.bool8

except Exception as e:
    # Безопасный вывод ошибки, если фикс не удался
    print(json.dumps({"error": f"Critical Numpy Fix Failed: {str(e)}"}))
    sys.exit(1)

# Настройка вывода для Ruby
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

# Импортируем YOLO только после применения всех хаков
try:
    from ultralytics import YOLO
except ImportError as e:
    print(json.dumps({"error": f"YOLO Import Failed: {str(e)}"}))
    sys.exit(1)

def run_prediction(image_path, model_path):
    try:
        # 1. Инициализация модели
        model = YOLO(model_path)
        
        # 2. Настройка путей сохранения (относительно корня Rails)
        base_path = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        project_path = os.path.join(base_path, "public", "analysis")
        
        if not os.path.exists(project_path):
            os.makedirs(project_path, exist_ok=True)
            
        save_dir = os.path.join(project_path, "predict")
        if os.path.exists(save_dir):
            shutil.rmtree(save_dir)
        
        # 3. Запуск анализа
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
        # Извлекаем имена найденных классов
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        # 4. Логика оценки качества (отель)
        conf_value = 0.0
        if len(result.boxes.conf) > 0:
            # .item() превращает тензор в обычное число
            conf_value = float(result.boxes.conf.mean().item()) * 100

        # Список меток, считающихся нарушениями
        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        output_filename = os.path.basename(result.path)

        # 5. Формирование финального ответа для Ruby
        output = {
            "is_approved": is_approved,
            "confidence": round(conf_value, 2),
            "objects": [{"name": str(cls), "count": int(detected_classes.count(cls))} for cls in set(detected_classes)],
            "issues": list(set(found_issues)),
            "feedback": "Стандарты чистоты соблюдены" if is_approved else f"Обнаружены проблемы: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        # Вывод ТОЛЬКО JSON в stdout
        print(json.dumps(output, ensure_ascii=False))
        sys.stdout.flush()
        
    except Exception as e:
        error_output = {"error": str(e)}
        print(json.dumps(error_output, ensure_ascii=False))
        sys.stdout.flush()

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])