# README #

This README would normally document whatever steps are necessary to get your application up and running.

### What is this repository for? ###

* Quick summary
* Version
* [Learn Markdown](https://bitbucket.org/tutorials/markdowndemo)

### Настройки системы для работы проекта ###

#### Git репозиторий

Адрес репозитория для хранения метаданных: [solombala-archive/metadata](https://gitlab.com/solombala-archive/metadata)

##### Настройка доступа

1. Создать аккаунт на gitlab.com
2. Создать ssh ключ для пользователя
```ssh-keygen -f ~/.ssh/solombala-gitlab -t ed25519 -C "Key for akrivopolenov@gmail.com for solombala archive"```

    2.1 добавить ключ и имя пользователя в `.ssh/config` файл
    ```
    #GitLab.com
    Host gitlab.com
	    User akrivopolenov
  	    PreferredAuthentications publickey
  	    IdentityFile ~/.ssh/solombala-gitlab
    ```
3. Загрузить ключ в аккаунт gitlab.com
4. Проверить, что ключ работает: `ssh -T git@gitlab.com`

##### Репозиторий в папке metadata

Если папки `metadata` не существует в папке с результатами обработки, то можно ее скачать с внешнего репозитория:

`git checkout git@gitlab.com:solombala-archive/metadata.git`

Если папка `metadata` существует, нужно проверить, есть ли в ней git и есть ли ссылка на внешний репозиторий

```
ls -al | grep  .git
drwxr-xr-x@ 9 akrivopolenov  staff    288 Jun  7 21:45 .git
```
если пусто, то:
```
git init
git remote add origin git@gitlab.com:solombala-archive/metadata
```

### Contribution guidelines ###

* Writing tests
* Code review
* Other guidelines

### Who do I talk to? ###

* Repo owner or admin
* Other community or team contact