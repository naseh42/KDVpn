from fastapi import APIRouter, Request, Form, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

router = APIRouter()
templates = Jinja2Templates(directory="backend/templates")

# لیست دامنه‌ها
domains = ["example.com", "test.com"]

# نمایش صفحه دامنه‌ها
@router.get("/domains", response_class=HTMLResponse)
async def show_domains(request: Request, lang: str = "fa"):
    return templates.TemplateResponse("domains.html", {"request": request, "lang": lang, "domains": domains})

# افزودن دامنه
@router.post("/add-domain", response_class=HTMLResponse)
async def add_domain(request: Request, domain: str = Form(...), lang: str = "fa"):
    if domain not in domains:
        domains.append(domain)
    return templates.TemplateResponse("domains.html", {"request": request, "lang": lang, "domains": domains})

# حذف دامنه
@router.post("/remove-domain", response_class=HTMLResponse)
async def remove_domain(request: Request, domain: str = Form(...), lang: str = "fa"):
    if domain in domains:
        domains.remove(domain)
    return templates.TemplateResponse("domains.html", {"request": request, "lang": lang, "domains": domains})
