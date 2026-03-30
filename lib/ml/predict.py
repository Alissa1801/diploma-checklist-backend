import sys
import os
import json
import warnings
import shutil

# --- УЛЬТИМАТИВНЫЙ ЯДЕРНЫЙ ФИКС NUMPY 2.0 ---
try:
    import numpy as np
    
    # 1. Эмуляция отсутствующих атрибутов для OpenCV (исправляет AttributeError)
    if not hasattr(np, '_globals'):
        class MockGlobals:
            _signature_descriptor = None
        np._globals = MockGlobals()
    
    # 2. Регистрация модулей в системных путях Python
    sys.modules['np'] = np
    
    # 3. Фикс для старых C-расширений (исправляет ImportError: multiarray)
    if hasattr(np, "core"):
        sys.modules['numpy.core.multiarray'] = np.core.multiarray
    
    # 4. РЕШЕНИЕ ОШИБКИ: expected np.ndarray (got numpy.ndarray)
    # Принудительно заставляем систему считать np.ndarray базовым типом массива
    np.ndarray = type(np.array([]))
    
    # 5. Базовые алиасы типов для совместимости
    if not hasattr(np, "float_"):
        np.float_ = np.float64
    if not hasattr(np, "int_"):
        np.int_ = np.int64

except Exception as e:
    # Если фикс не удался, Ruby получит понятную ошибку
    print(json.dumps({"error": f"Critical Numpy Fix Failed: {str(e)}"}))
    sys.exit(1)

# Настройка вывода для корректной передачи JSON в Ruby
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

# Импорт YOLO только после того, как Numpy "исправлен"
try:
    from ultralytics import YOLO
except ImportError as e:
    print(json.dumps({"error": f"YOLO Import Failed: {str(e)}"}))
    sys.exit(1)

def run_prediction(image_path, model_path):
    try:
        # 1. Инициализация модели
        model = YOLO(model_path)
        
        # 2. Настройка путей сохранения
        base_path = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        project_path = os.path.join(base_path, "public", "analysis")
        
        if not os.path.exists(project_path):
            os.makedirs(project_path, exist_ok=True)
            
        save_dir = os.path.join(project_path, "predict")
        if os.path.exists(save_dir):
            shutil.rmtree(save_dir)
        
        # 3. Запуск анализа нейросетью
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
        # Безопасное извлечение имен классов
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        # 4. Логика оценки качества
        conf_value = 0.0
        if len(result.boxes.conf) > 0:
            # .item() превращает тензор PyTorch в обычное число Python
            conf_value = float(result.boxes.conf.mean().item()) * 100

        # Список меток-нарушений
        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        output_filename = os.path.basename(result.path)

        # 5. Формирование JSON для Ruby
        output = {
            "is_approved": is_approved,
            "confidence": round(conf_value, 2),
            "objects": [{"name": str(cls), "count": int(detected_classes.count(cls))} for cls in set(detected_classes)],
            "issues": list(set(found_issues)),
            "feedback": "Стандарты чистоты соблюдены" if is_approved else f"Обнаружены проблемы: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        # Вывод результата
        print(json.dumps(output, ensure_ascii=False))
        sys.stdout.flush()
        
    except Exception as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        sys.stdout.flush()

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])