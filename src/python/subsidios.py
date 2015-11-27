import sys
import os

import sqlalchemy
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

import xml.etree.ElementTree as etree


Base = declarative_base()


engine = sqlalchemy.create_engine(
        'postgresql://bacia:bacia@localhost:15432/bacia', echo=True)


Session = sessionmaker(bind=engine)


class XMLType(sqlalchemy.types.TypeDecorator):
    """http://stackoverflow.com/q/8530858
    """

    impl = sqlalchemy.types.UnicodeText
    type = etree.Element

    def get_col_spec(self):
        return 'xml'

    def bind_processor(self, dialect):
        def process(value):
            if value is not None:
                return etree.tostring(value, encoding='utf-8')
            else:
                return None
        return process

    def process_result_value(self, value, dialect):
        if value is not None:
            value = etree.fromstring(value)
        return value


class Artigo(Base):
    __tablename__ = 'artigo'

    id = sqlalchemy.Column(sqlalchemy.Integer, primary_key=True)
    pid = sqlalchemy.Column(sqlalchemy.String)
    conteudo = sqlalchemy.Column(XMLType)
    info = sqlalchemy.Column(sqlalchemy.String, default='')
    kx = sqlalchemy.Column(sqlalchemy.String, default='')
    info_modified = sqlalchemy.Column(sqlalchemy.DateTime(timezone=True))

    def __repr__(self):
        return '<Artigo id="%s">' % self.id


def init_database(base, engine):
    """
    Creates the database structure for the application.
    """
    base.metadata.create_all(engine)


if __name__ == '__main__':
    session = Session()

    for caminho_xml in sys.argv[1:]:

        pid, _ = os.path.basename(caminho_xml).rsplit('.', 1)

        with open(caminho_xml, 'r') as xml:
            xml = xml.read()

        artigo = Artigo(pid=pid, conteudo=xml)
        session.add(artigo)

    session.commit()

