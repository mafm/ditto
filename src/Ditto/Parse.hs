module Ditto.Parse where
import Ditto.Syntax
import Text.Parsec (parse, try)
import Text.Parsec.String
import Text.Parsec.Char
import Text.Parsec.Combinator
import Control.Applicative ((<*), many, (<$>), (<*>))
import Control.Monad

----------------------------------------------------------------------

parseE = parse (whitespace >> parseExp <* eof) "" . stripComments
parseP = parse (whitespace >> parseStmts <* eof) "" . stripComments

stripComments :: String -> String
stripComments = unlines . map (takeWhile (/= '#')) . lines

keyType = symbol "Type"
keyData = symbol "data"
keyDef = symbol "def"
keyWhere = symbol "where"
keyEnd = symbol "end"

keywords = choice
  [keyType, keyData, keyDef, keyWhere, keyEnd]

symAscribe = symbol ":"
symChoice = symbol "|"
symInacc = symbol "*"
symEq = symbol "="
symArr = symbol "->"
symSlash = symbol "/"

symLParen = symbol "("
symRParen = symbol ")"

----------------------------------------------------------------------

parseStmts :: Parser [Stmt]
parseStmts = many1 $ choice [
    parseDef
  , parseDefn
  , parseData
  ]

parseDef :: Parser Stmt
parseDef = try $ do
  keyDef
  x <- parseName
  optional $ symAscribe
  _A <- parseExp
  keyWhere
  a <- parseExp
  keyEnd
  return $ SDef x a _A

----------------------------------------------------------------------

parseDefn :: Parser Stmt
parseDefn = try $ do
  keyDef
  x <- parsePName
  optional $ symAscribe
  _A <- parseExp
  keyWhere
  cs <- many1 parseClause
  keyEnd
  return $ SDefn x _A cs

parseClause :: Parser Clause
parseClause = try $ do
  symChoice
  ps <- many parsePattern
  symEq
  a <- parseExp
  return (ps , a)

----------------------------------------------------------------------

parsePattern :: Parser Pat
parsePattern = choice
  [ parsePVar
  , parsePInacc
  , parsePCon
  ]

parsePCon :: Parser Pat
parsePCon = try $ parens $ do
  x <- parsePName
  xs <- many parsePattern
  return $ PCon x xs

parsePVar :: Parser Pat
parsePVar = try $ PVar <$> parseName

parsePInacc :: Parser Pat
parsePInacc = try $ do
  symInacc
  return $ Inacc Nothing

----------------------------------------------------------------------

parseData :: Parser Stmt
parseData = try $ do
  keyData
  x <- parsePName
  optional $ symAscribe
  _A <- parseExp
  keyWhere
  cons <- many parseCon
  keyEnd
  return $ SData x _A (concat cons)

parseCon :: Parser Cons
parseCon = try $ do
  symChoice
  xs <- slashSep parsePName
  optional $ symAscribe
  _A <- parseExp
  return (map (\x -> (x, _A)) xs)

----------------------------------------------------------------------

parseExp :: Parser Exp
parseExp = choice [
    parsePi
  , parseLam
  , parseApps
  ]

parseApps :: Parser Exp
parseApps = apps <$> parseAtom <*> many parseAtom

parseAtom :: Parser Exp
parseAtom = choice [
    parens parseExp
  , parseType
  , parseVar
  ]

----------------------------------------------------------------------

parseType :: Parser Exp
parseType = try $ keyType >> return Type

parseVar :: Parser Exp
parseVar = try $ Var <$> parseName

parsePName :: Parser PName
parsePName = PName <$> parseIdent

parseName :: Parser Name
parseName = s2n <$> parseIdent

parseIdent :: Parser String
parseIdent = try $ do
  notFollowedBy keywords
  lexeme ((:) <$> firstChar <*> many nextChar)
  where
  firstChar = letter
  nextChar = choice [alphaNum, char '\'']

----------------------------------------------------------------------

parsePi :: Parser Exp
parsePi = try $ do
  _As <- parseTel
  symAscribe
  _A <- parseExp
  return $ pis _As _A

parseLam :: Parser Exp
parseLam = try $ do
  _As <- parseTel
  symArr
  b <- parseExp
  return $ lams _As b

----------------------------------------------------------------------

parseTel :: Parser Tel
parseTel = concat <$> many1 (parens parseAnnot)

parseAnnot :: Parser Tel
parseAnnot = do
  xs <- many1 parseName
  symAscribe
  a <- parseExp
  return $ map (\ x -> (x , a)) xs

----------------------------------------------------------------------

slashSep :: Parser a -> Parser [a]
slashSep p = p `sepBy1` symSlash

parens :: Parser a -> Parser a
parens = between symLParen symRParen

symbol :: String -> Parser String
symbol s = lexeme $ string s

lexeme :: Parser a -> Parser a
lexeme p = p <* whitespace

whitespace :: Parser ()
whitespace = void $ many $ oneOf " \n\t"

----------------------------------------------------------------------
