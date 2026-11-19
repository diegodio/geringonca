# Ligar a Geringonça ao Supabase

O jogo já tem tudo pronto para contas, login e progresso na nuvem. Falta só
criar o projeto no Supabase e dizer ao jogo onde ele está. Leva uns 15 minutos.

Enquanto isso não for feito, o jogo funciona como antes: tudo no aparelho, sem
conta e sem limite de fases.

## 1. Criar o projeto

1. Entre em https://supabase.com e crie uma conta (pode ser com o GitHub).
2. **New project**. Dê um nome (por exemplo `geringonca`), escolha uma senha
   forte para o banco (guarde-a; o jogo não precisa dela) e a região
   **South America (São Paulo)**.
3. Espere o projeto ficar pronto (uns 2 minutos).

## 2. Criar as tabelas

1. No menu da esquerda, abra **SQL Editor** → **New query**.
2. Copie todo o conteúdo de `supabase/migrations/0001_geringonca.sql` (neste
   repositório), cole e clique em **Run**. Deve aparecer "Success".

Isso cria as tabelas `profiles` (nome de cada pessoa), `progress` (progresso)
e `levels` (fases criadas no editor), com regras de segurança: cada pessoa só
vê e altera o que é dela.

## 3. Configurar o login por e-mail

Em **Authentication**:

1. **Sign In / Providers** → **Email**: deixe ligado. "Confirm email" ligado é o
   recomendado (a pessoa confirma o e-mail antes de entrar).
2. **URL Configuration**:
   - **Site URL**: `https://diegodio.github.io/geringonca/`
   - **Redirect URLs** → **Add URL**: `https://diegodio.github.io/geringonca/**`

   É para onde o link do e-mail (confirmar a conta, esqueci minha senha) leva.
3. (Opcional) **Emails** → **Templates**: traduza os textos dos e-mails para o
   português.

> O e-mail padrão do Supabase manda poucas mensagens por hora: serve para
> testes. Quando muita gente estiver criando conta, ligue um serviço de e-mail
> próprio em **Authentication → Emails → SMTP Settings** (Resend, Brevo...).

## 4. Pegar o endereço e a chave pública

Em **Project Settings → API Keys** (ou no botão **Connect** do topo):

- **Project URL**: algo como `https://abcdxyz.supabase.co`
- **Publishable key**: começa com `sb_publishable_...` (em projetos antigos, a
  chave "anon public" também serve)

Essas duas informações são públicas por natureza: vão dentro do jogo e qualquer
pessoa poderia vê-las. Quem protege os dados são as regras do passo 2.

**Nunca** use a chave `secret` / `service_role` no jogo.

## 5. Contar ao jogo

No GitHub, no repositório `diegodio/geringonca`:

1. **Settings → Secrets and variables → Actions → aba Variables** →
   **New repository variable**:
   - `SUPABASE_URL` = o Project URL
   - `SUPABASE_PUBLISHABLE_KEY` = a Publishable key
2. Publique de novo: **Actions → Deploy Flutter Web → Run workflow** (ou faça
   qualquer merge na `main`).

Pronto: no menu aparece o botão da conta, e sem conta só as 7 primeiras fases
ficam abertas.

## Rodar no computador

```
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://abcdxyz.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Para testar o login no computador, acrescente `http://localhost:*/**` nas
Redirect URLs do passo 3.

## Como funciona por dentro

- `lib/net/backend.dart`: fala com o Supabase (login, progresso, fases).
- `lib/game/account.dart`: a conta no jogo e a sincronização. Ao entrar, o
  progresso do aparelho e o da nuvem se juntam (fica o melhor de cada um:
  fases concluídas, medalhas, recordes, melhores soluções); depois, cada
  mudança vai para a nuvem alguns segundos depois. Sem internet, tudo continua
  no aparelho e vai na próxima vez.
- `lib/game/progress_sync.dart`: a regra de juntar o progresso.
- Fases criadas no editor vão para a tabela `levels`, com `is_public` falso.
  A coluna já existe para uma galeria de fases da comunidade no futuro.
- O limite de 7 fases sem conta fica em `kGuestLevels`, em
  `lib/game/progress.dart`.
