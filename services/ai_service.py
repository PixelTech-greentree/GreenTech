"""
AI Service with balanced validation for OpenAI GPT-4o Vision
"""
import os
import json
import base64
from typing import Dict
from datetime import datetime
from openai import AsyncOpenAI


class AIService:
    def __init__(self):
        self.client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.model = "gpt-4o"

    def _log(self, message: str, data: any = None):
        """Print log with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [AI] {message}")
        if data:
            if isinstance(data, dict):
                print(f"[{timestamp}] [AI] Data: {json.dumps(data, ensure_ascii=False, indent=2)}")
            else:
                print(f"[{timestamp}] [AI] Data: {data}")

    async def analyze_single_image(self, image_bytes: bytes) -> Dict:
        """
        Analyze tree image with balanced validation

        Returns:
        {
            "is_tree": bool,
            "is_real_photo": bool,
            "is_seedling": bool,
            "maturity": str,
            "health": str,
            "soil_moisture": str,
            "comment": str (Uzbek)
        }
        """
        self._log(f"Rasm tahlili boshlandi, hajmi: {len(image_bytes)} bytes")
        
        base64_image = base64.b64encode(image_bytes).decode('utf-8')

        prompt = """Sen daraxt va o'simliklarni aniqlash bo'yicha mutaxassissan.
Rasmni tahlil qilib, FAQAT JSON formatida javob ber.

DARAXT DEYISH UCHUN (is_tree = true):
✅ Har qanday daraxt: katta, kichik, yosh, qari
✅ Ko'chat (nihollar)
✅ Buta (kustlar)
✅ Gullar tuproqda o'sgan
✅ O'simlik tuproq yoki qo'ldagi idishda
✅ Bog', hovli, ko'cha, dala, o'rmondagi o'simliklar

DARAXT EMAS (is_tree = false):
❌ Elektron qurilmalar: telefon, kompyuter, televizor
❌ Mebel: stol, stul, shkaf
❌ Transport: mashina, velosiped
❌ Qurilish: bino, devor (o'simliksiz)
❌ Hayvonlar, odamlar (o'simliksiz)
❌ Ovqat, idish-tovoq

HAQIQIY RASM (is_real_photo = true):
✅ Telefon kamerasi bilan olingan
✅ Tashqarida yoki xonada jonli o'simlik
✅ Biroz xira yoki yorug' bo'lsa ham OK

HAQIQIY EMAS (is_real_photo = false):
❌ Ekrandan screenshot
❌ Qog'ozga chop etilgan rasm
❌ Kompyuterda chizilgan rasm
❌ AI yaratgan rasm
 
KO'CHAT (is_seedling = true):

✅ Agar daraxt yoki o'simlikning umumiy balandligi taxminan 2 metrga yaqin yoki undan past
   (maksimal ~210 sm) ko'rinsa – is_seedling = true QIL
✅ Ichki xonada idishda ekilgan daraxtlar ham, balandligi 2.1 m dan kichik bo'lsa,
   is_seedling = true bo'lishi kerak
✅ FAQAT juda katta, shiftga yetadigan yoki taxminan 2.1 metrdan BALAND daraxtlarda
   is_seedling = false qil
❗ Poyaning qalinligi va yoshi muhim emas, asosiy mezon – balandlik

maturity qiymatlari:
- "seedling": juda kichik, 0-30 sm
- "young": o'sib kelayotgan, 30-150 sm
- "mature": katta daraxt, 150+ sm

❗ Eslatma:
is_seedling va maturity alohida:
- Daraxt balandligi 2.1 m dan past bo'lsa, maturity "young" yoki "mature"
  bo'lsa ham is_seedling = true bo'lishi mumkin.

health qiymatlari:
- "healthy": barglar yashil, sog'lom
- "stressed": sariq barglar, so'lib qolgan
- "critical": qurib qolgan, jiddiy zarar
- "unknown": aniqlab bo'lmaydi

soil_moisture qiymatlari:
- "dry": tuproq quruq, yorilgan
- "normal": oddiy tuproq
- "wet": ho'l, suv bor
- "unknown": tuproq ko'rinmaydi

FAQAT JSON QAYTAR (boshqa matn yo'q):
{
  "is_tree": true yoki false,
  "is_real_photo": true yoki false,
  "is_seedling": true yoki false,
  "maturity": "seedling" yoki "young" yoki "mature" yoki "unknown",
  "health": "healthy" yoki "stressed" yoki "critical" yoki "unknown",
  "soil_moisture": "dry" yoki "normal" yoki "wet" yoki "unknown",
  "comment": "O'zbek tilida qisqa izoh (1-2 jumla)"
}"""

        try:
            self._log("OpenAI API ga so'rov yuborilmoqda...")
            
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_image}"
                                }
                            }
                        ]
                    }
                ],
                max_tokens=800,
                temperature=0.3
            )

            content = response.choices[0].message.content.strip()
            self._log(f"OpenAI javob berdi (raw): {content[:200]}...")

            # Clean JSON
            if content.startswith("```json"):
                content = content[7:]
            if content.startswith("```"):
                content = content[3:]
            if content.endswith("```"):
                content = content[:-3]
            content = content.strip()

            result = json.loads(content)
            self._log("JSON muvaffaqiyatli parse qilindi", result)

            # Validate required fields
            required = ["is_tree", "is_real_photo", "is_seedling", "maturity", "health", "soil_moisture", "comment"]
            for field in required:
                if field not in result:
                    self._log(f"Maydon topilmadi, default qo'yilmoqda: {field}")
                    if field in ["is_tree", "is_real_photo", "is_seedling"]:
                        result[field] = False
                    elif field == "comment":
                        result[field] = "Ma'lumot yo'q"
                    else:
                        result[field] = "unknown"

            # Log final result
            self._log("=== TAHLIL NATIJASI ===")
            self._log(f"  🌳 Daraxt: {'HA' if result['is_tree'] else 'YO`Q'}")
            self._log(f"  📷 Haqiqiy rasm: {'HA' if result['is_real_photo'] else 'YO`Q'}")
            self._log(f"  🌱 Ko'chat: {'HA' if result['is_seedling'] else 'YO`Q'}")
            self._log(f"  📏 Yetuklik: {result['maturity']}")
            self._log(f"  💚 Salomatlik: {result['health']}")
            self._log(f"  💧 Tuproq namligi: {result['soil_moisture']}")
            self._log(f"  💬 Izoh: {result['comment']}")
            self._log("========================")

            return result

        except json.JSONDecodeError as e:
            self._log(f"JSON parse xatosi: {e}")
            self._log(f"Xato content: {content}")
            return {
                "is_tree": False,
                "is_real_photo": False,
                "is_seedling": False,
                "maturity": "unknown",
                "health": "unknown",
                "soil_moisture": "unknown",
                "comment": "Tahlil xatosi - javob noto'g'ri formatda"
            }
        except Exception as e:
            self._log(f"AI xatolik: {type(e).__name__}: {e}")
            raise

    async def compare_images(
        self,
        previous_image_bytes: bytes,
        current_image_bytes: bytes
    ) -> Dict:
        """Compare two images"""
        self._log(f"Ikki rasm solishtirilmoqda")
        self._log(f"  Oldingi rasm: {len(previous_image_bytes)} bytes")
        self._log(f"  Yangi rasm: {len(current_image_bytes)} bytes")
        
        base64_prev = base64.b64encode(previous_image_bytes).decode('utf-8')
        base64_curr = base64.b64encode(current_image_bytes).decode('utf-8')

        prompt = """Ikki rasmni solishtir va FAQAT JSON qaytar.

Birinchi rasm - OLDINGI holat
Ikkinchi rasm - HOZIRGI holat

TEKSHIR:
1. Ikkalasida ham daraxt/o'simlik bormi?
2. Bir xil daraxtmi yoki boshqasimi?
3. O'zgarish bormi (o'sgan, sug'orilgan, so'ligan)?

same_scene = true FAQAT agar:
- Xuddi bir xil rasm (copy)
- Yoki bir xil joy, bir xil burchak, bir xil vaqt (firibgarlik)

{
  "is_tree": true/false,
  "is_real_photo": true/false,
  "is_seedling": true/false,
  "same_scene": true/false,
  "maturity": "seedling"/"young"/"mature"/"unknown",
  "health": "healthy"/"stressed"/"critical"/"unknown",
  "soil_moisture": "dry"/"normal"/"wet"/"unknown",
  "changes": "Qanday o'zgarish bo'lgan",
  "comment": "Umumiy baho"
}

FAQAT JSON!"""

        try:
            self._log("OpenAI API ga solishtirish so'rovi yuborilmoqda...")
            
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "OLDINGI RASM:"},
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:image/jpeg;base64,{base64_prev}", "detail": "low"}
                            },
                            {"type": "text", "text": "YANGI RASM:"},
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:image/jpeg;base64,{base64_curr}"}
                            },
                            {"type": "text", "text": prompt}
                        ]
                    }
                ],
                max_tokens=1000,
                temperature=0.3
            )

            content = response.choices[0].message.content.strip()
            self._log(f"OpenAI javob berdi (raw): {content[:200]}...")
            
            if content.startswith("```json"):
                content = content[7:]
            if content.startswith("```"):
                content = content[3:]
            if content.endswith("```"):
                content = content[:-3]
            content = content.strip()

            result = json.loads(content)
            self._log("JSON muvaffaqiyatli parse qilindi", result)

            # Set defaults for missing fields
            defaults = {
                "is_tree": False,
                "is_real_photo": False,
                "is_seedling": False,
                "same_scene": False,
                "maturity": "unknown",
                "health": "unknown",
                "soil_moisture": "unknown",
                "changes": "Aniqlanmadi",
                "comment": "Ma'lumot yo'q"
            }

            for k, v in defaults.items():
                if k not in result:
                    self._log(f"Maydon topilmadi, default qo'yilmoqda: {k}")
                    result[k] = v

            # Log comparison result
            self._log("=== SOLISHTIRISH NATIJASI ===")
            self._log(f"  🌳 Daraxt: {'HA' if result['is_tree'] else 'YO`Q'}")
            self._log(f"  📷 Haqiqiy: {'HA' if result['is_real_photo'] else 'YO`Q'}")
            self._log(f"  🔄 Bir xil sahna: {'HA (firibgarlik!)' if result['same_scene'] else 'YO`Q'}")
            self._log(f"  📝 O'zgarishlar: {result['changes']}")
            self._log(f"  💬 Izoh: {result['comment']}")
            self._log("==============================")

            return result

        except json.JSONDecodeError as e:
            self._log(f"JSON parse xatosi: {e}")
            self._log(f"Xato content: {content}")
            return {
                "is_tree": False,
                "is_real_photo": False,
                "is_seedling": False,
                "same_scene": False,
                "maturity": "unknown",
                "health": "unknown",
                "soil_moisture": "unknown",
                "changes": "Xato",
                "comment": "Tahlil xatosi - javob noto'g'ri formatda"
            }
        except Exception as e:
            self._log(f"AI solishtirish xatolik: {type(e).__name__}: {e}")
            raise
