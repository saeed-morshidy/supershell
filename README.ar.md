<div dir="rtl">

# supershell

**بيئة Bash حديثة ومدروسة لـ Ubuntu 26.04.** سطر أوامر أنيق، وبحث ذكي، وتنقّل سريع بين المجلدات، وعرض واضح لتغييرات Git، ومحرر Neovim جاهز للعمل، ومعلومات DevOps في الـ prompt. ومع كل هذا تظل الـ shell عندك Bash عاديًا، وكل الأوامر الأساسية تعمل تمامًا كما تعمل على أي جهاز أو سيرفر Ubuntu آخر.

[English](README.md) · [دعم اللغة العربية](docs/arabic.md) · [لماذا اخترنا هذه الأدوات](docs/technology-selection.md)

## المبادئ

- **Bash يظل Bash.** لا نعيد تعريف `ls` أو `cat` أو `grep` أو `find` أو `cd` أو `vi` أبدًا. الأدوات الجديدة لها أسماء خاصة بها (`ll` و`bat` و`rg` و`z`). والـ scripts و`scp` و`rsync` لا تتأثر، لأن supershell لا يعمل إلا في الـ shell التفاعلية.
- **سطر واحد في `~/.bashrc`.** داخل block واضح العلامات، مع نسخة احتياطية قبل التعديل، ويُحذف عند الإزالة فيعود الملف كما كان بالضبط.
- **سريع.** لا framework ولا عمليات تعمل في الخلفية ولا اتصال بالإنترنت عند فتح الـ terminal. والأمر `supershell bench` يقيس التكلفة الحقيقية على جهازك.
- **آمن للتجربة.** كل تشغيل يُعامَل كوحدة واحدة: لو فشل أي جزء أو ضغطت Ctrl-C يرجع كل شيء كما كان. والأمر `supershell mode classic` يرجعك إلى Bash الأصلي فورًا.
- **العربية مُختبَرة**، وحدودها موثّقة بصراحة.

## التثبيت

```bash
git clone https://github.com/saeed-morshidy/supershell.git
cd supershell
./supershell install --dry-run   # يعرض ما سيُثبَّت ومن أين، بدون تنفيذ أي شيء
./supershell install
```

أول تثبيت يسألك سؤالين:

- **شكل الـ prompt** — *supershell-theme* (الافتراضي): ثيم supershell الخاص — شريط ألوان بعرض الـ terminal كله، وطرفاه مربّعان، والساعة على اليمين — أو *starship*: شكل pastel-powerline [كما ينشره starship](https://starship.rs/presets/) بالضبط. الخياران `--custom` و`--default`، وترجع للافتراضي في أي وقت بـ `supershell theme reset`.
- **خط الـ terminal** — DejaVu Sans Mono (الافتراضي)، أو Cascadia Code، أو JetBrains Mono، أو Fira Code، أو IBM Plex Mono، أو Ubuntu Sans Mono، من أرشيف Ubuntu. الخيار `--font=NAME`، وتقدر تغيّر لاحقًا بـ `supershell font <name>`.

و`--yes` تختار الافتراضي في الاثنين.

بعد التثبيت افتح terminal جديدًا، ثم شغّل `supershell doctor` للتأكد من أن كل شيء سليم.

## الأوامر اليومية

| الأمر | الوظيفة |
|---|---|
| `supershell mode classic` | Bash الأصلي، مناسب وأنت تتابع شرحًا أو كورسًا |
| `supershell mode modern` | تجربة supershell الكاملة |
| `supershell devops on/off` | تشغيل أو إيقاف معلومات DevOps في الـ prompt والـ completion |
| `supershell devops aliases on` | اختصارات مثل `k` و`d` (مُطفأة افتراضيًا، والأفضل أن تتعلم الأوامر كاملة أولًا) |
| `supershell theme` | ثيم supershell (الافتراضي): `theme colors <name>` لتغيير الألوان (supershell، pastel، nord، dracula…)، و`theme root-colors <name>` لألوان الـ root (الافتراضي أحمر `supershell-root`)، و`theme reset` للرجوع للأصل |
| `supershell prompt [<style>]` | أشكال تانية: `pastel-powerline`، `tokyo-night`، `gruvbox-rainbow`، `catppuccin-mocha`… |
| `supershell prompt custom on/off` | شكل supershell (بعرض الشاشة وطرفاه مربّعان — الافتراضي) أو شكل starship كما هو؛ و`prompt cap on` يرجّع البداية المدوّرة |
| `supershell prompt edit` | تعديلاتك أنت على الـ prompt (`~/.config/supershell/prompt.toml`)، وتبقى مع أي شكل وبعد أي تحديث |
| `supershell font [<name>]` | خط الـ terminal (DejaVu Sans Mono، Cascadia Code، JetBrains Mono…)، والعربي دائمًا بعرض ثابت؛ Ptyxis يتحدّث فورًا |
| `supershell root on/off` | نفس شكل الـ prompt وأنت root (`su -` أو `sudo -i`) — نسخ يملكها root، والـ prompt فقط، ويطلب sudo مرة واحدة |
| `supershell keys` | ملخص الاختصارات |
| `supershell doctor` | فحص سلامة البيئة |
| `supershell uninstall` | إزالة كل ما أضافه supershell (ملفاتك الشخصية تبقى كما هي) |

## الوحدات (modules)

الوحدات المُثبَّتة افتراضيًا هي `core` و`git` و`editor` و`fonts` و`devops`. والوحدات الاختيارية هي `lazygit` و`helix` و`plus` و`tmux`.

## العربية

تدعم الـ terminal الافتراضية في Ubuntu 26.04 (Ptyxis، المبنية على VTE) عرض النص من اليمين لليسار وتشكيل الحروف. وتضبط supershell خطًا يعرض الحروف العربية متصلة بشكل سليم. يوجد حد معروف: في السطر الذي يخلط العربي والإنجليزي، قد يظهر المؤشر (cursor) في مكان غير متوقع، مع أن النص نفسه صحيح. التفاصيل الكاملة في [docs/arabic.md](docs/arabic.md).

## المساهمة

المشروع مفتوح المصدر بترخيص MIT، وأي شخص يمكنه نسخه وتعديله واقتراح تغييرات. لكن دمج أي تغيير في المستودع الرسمي يحتاج **موافقة 3 مشرفين (maintainers) على الأقل**. التفاصيل في [GOVERNANCE.md](GOVERNANCE.md).

</div>
