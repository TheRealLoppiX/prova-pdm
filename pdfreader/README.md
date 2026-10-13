# PDF Reader

Aplicativo em Flutter para ler, editar e baixar arquivos PDF, inspirado no [iLovePDF](https://www.ilovepdf.com/). Funciona no Android e no navegador.

Todo o processamento acontece no próprio dispositivo, então os arquivos não são enviados para nenhum servidor.

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-suportado-3DDC84?logo=android&logoColor=white)
![Web](https://img.shields.io/badge/Web-suportado-4285F4?logo=googlechrome&logoColor=white)

## Funcionalidades

| Ferramenta | Descrição |
|---|---|
| Ler e editar PDF | Leitura com busca, zoom e navegação por página. Permite destacar, sublinhar, riscar, adicionar notas e escrever texto na página, com escolha de cor. Tem desfazer e refazer, e o PDF editado pode ser baixado. |
| Juntar PDF | Junta vários PDFs em um só, na ordem escolhida. |
| Dividir PDF | Divide por intervalos (ex.: `1-3, 5, 8-10`), separa cada página em um arquivo ou extrai páginas para um único PDF. |
| Organizar PDF | Mostra as miniaturas das páginas para reordenar (segurando e arrastando), girar ou excluir. |
| Girar PDF | Gira uma página ou todas de uma vez. |
| Remover páginas | Exclui as páginas selecionadas. |
| Imagem para PDF | Converte imagens JPG e PNG em PDF, em folha A4 ou no tamanho original da imagem. |
| Marca d'água | Aplica um texto em todas as páginas, com tamanho, cor, transparência e orientação configuráveis. |
| Numerar páginas | Adiciona a numeração em uma de seis posições, com número inicial e formato "Página X de Y" opcionais. |
| Proteger PDF | Protege o arquivo com senha usando criptografia AES de 256 bits. |
| Desbloquear PDF | Remove a senha de um PDF, desde que a senha atual seja informada. |
| PDF para imagem | Exporta cada página como PNG, com resolução entre 72 e 300 DPI. |
| Extrair texto | Salva o texto do PDF em um arquivo `.txt`. |

Ao terminar qualquer operação, o resultado pode ser baixado ou aberto no editor. Quando a ferramenta gera mais de um arquivo, eles podem ser baixados juntos em um `.zip`.

## Como executar

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.47 ou superior e, para Android, o Android SDK.

```bash
flutter pub get

# navegador
flutter run -d chrome

# Android (dispositivo ou emulador)
flutter run

# gerar o APK
flutter build apk --release
```

Observação para Windows: o Flutter pode apresentar erro (`FormatException`) ao rodar `flutter analyze` ou `flutter test` em pastas com acento no caminho, como "Área de Trabalho". Nesse caso, basta mover o projeto para uma pasta sem acentos.

## Testes

```bash
flutter test
```

- `test/widget_test.dart`: verifica a leitura dos intervalos de páginas.
- `test/tools_test.dart`: gera PDFs e testa juntar, dividir, reordenar, girar, marca d'água, numeração, inserção de texto, proteção e desbloqueio, incluindo a recusa de senha incorreta.

## Estrutura do projeto

```
lib/
├── main.dart                     inicialização e tema
├── services/
│   ├── pdf_tools.dart            operações com PDF
│   └── file_service.dart         seleção, download e compactação de arquivos
├── widgets/
│   └── common.dart               componentes compartilhados
└── pages/
    ├── home_page.dart            tela inicial com as ferramentas
    ├── viewer_page.dart          leitor e editor
    ├── merge_page.dart           juntar
    ├── split_page.dart           dividir
    ├── organize_page.dart        organizar, girar e remover páginas
    ├── images_to_pdf_page.dart   imagem para PDF
    ├── single_tool_page.dart     marca d'água, numeração, senha, PDF para imagem e texto
    └── result_page.dart          tela de resultado
```

## Bibliotecas

- [pdfrx](https://pub.dev/packages/pdfrx): baseada no PDFium. Usada para juntar, dividir, organizar, girar, desbloquear, gerar miniaturas e imagens e extrair texto. Como trabalha direto com as páginas originais, links, formulários e anotações são preservados.
- [syncfusion_flutter_pdfviewer](https://pub.dev/packages/syncfusion_flutter_pdfviewer): visualizador com suporte a anotações.
- [syncfusion_flutter_pdf](https://pub.dev/packages/syncfusion_flutter_pdf): usada para inserir conteúdo no PDF (marca d'água, numeração, texto, imagens e senha).
- [file_picker](https://pub.dev/packages/file_picker): abrir e salvar arquivos no Android e na web.
- [archive](https://pub.dev/packages/archive): criação de arquivos `.zip`.

## Observações

- Na versão web, o visualizador depende do [pdf.js](https://mozilla.github.io/pdf.js/), carregado em `web/index.html`.
- No Android, o download abre a janela de salvar arquivo do sistema. No navegador, o arquivo vai para a pasta de downloads.
- PDFs escaneados, que contêm apenas imagens, não têm texto para extrair.
- As bibliotecas da Syncfusion são usadas sob a [licença Community](https://www.syncfusion.com/products/communitylicense), gratuita para uso individual e acadêmico.

## Autor

Arthur Vasconcelos, IF Sertão-PE.
