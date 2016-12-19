package Atol;
use strict;
use warnings;
use Device::SerialPort;
use Data::Dumper;
use Text::Iconv;
use vars qw($AUTOLOAD @ISA $VERSION $DEBUG);

@ISA      = qw(Device::SerialPort);
$VERSION  = '0.01';
$^W       = 1;
$DEBUG    = 1;
$|++;


BEGIN {
    use Exporter;
    our (@EXPORT,@ISA,@EXPORT_OK);
    @ISA = qw(Exporter);

    @EXPORT=qw(geterror);
    @EXPORT_OK=@EXPORT; 
}

#------------------------------
# Public Methods
#------------------------------

sub new {
    my ($class,%args) = @_;
    my $port = $args{port} || '/dev/ttyUSB0';
    my $baudrate = $args{boudrate} || '9600';
    my $password = $args{password} || '30';
    my $PortObj=Device::SerialPort->new($port) or die $!;
    $PortObj->baudrate($baudrate);
    $PortObj->parity('none');
    $PortObj->databits(8);
    $PortObj->stopbits(1);
    $PortObj->read_const_time(10000); 
    my $self = {
        baudrate => $baudrate,
        port     => $port,
        password => $password,
        PortObj => $PortObj
    };
    bless $self, $class;
}

sub con {
    return shift->{PortObj};
}

sub init {
    my $self=shift;
    print "send init 05\n" if $DEBUG;
    $self->con->write("\05");
    my ($count,$out)=$self->con->read(1);
    print "got status $count,".ord($out)."\n" if $DEBUG;
    
}

sub clearmode {
    my $self=shift;
    $self->init;
    $self->con->write(cmd2bin("48"));
    $self->getstatus;   
}

sub z {
    my $self=shift;
    $self->init;
    $self->clearmode;
    $self->init;
    $self->con->write(cmd2bin("56 03 00 00 00 30"));
    $self->getstatus;
    $self->init;
    $self->con->write(cmd2bin("5A"));
    $self->getstatus;   

}

sub x {
    my $self=shift;
    $self->clearmode;
    $self->init;
    $self->con->write(cmd2bin("56 02 00 00 00 30"));
    $self->getstatus;
    $self->init;
    $self->con->write(cmd2bin("67 01"));
    $self->getstatus;

}

sub s {
    my $self=shift;
    $self->clearmode;
    $self->init;
    $self->con->write(cmd2bin("56 02 00 00 00 30"));
    $self->getstatus;
    $self->init;
    $self->con->write(cmd2bin("67 02"));
    $self->getstatus;

}

sub cut 
{
    my $self=shift;
    $self->init;
    $self->con->write(cmd2bin("75 01"));
    $self->getstatus;      
}
sub printline
{
    my $self=shift;
    my $in_str=shift;
    print "$in_str";
    my $converter = Text::Iconv->new("utf8", "CP866");
    $in_str=~s/Ё/Е/g;
    $in_str=~s/ё/е/g;
    my $str = $converter->convert($in_str);
    $self->init;
    $self->con->write(cmd2bin('4C',$str));
    $self->getstatus;
}


sub beginsmena
{
    my $self=shift;
    $self->init;
    $self->con->write(cmd2bin("9A 00 91 AC A5 AD A0 20 8E E2 AA E0 EB E2 A0"));
    print "status ".$self->getstatus." \n";

}
sub stamp 
{
    my $self=shift;

    $self->init;
    $self->con->write(cmd2bin("6C"));
    $self->getstatus;
}

sub opencheck
{
    my $self=shift;
    $self->init;
    $self->con->write(cmd2bin("92 00 01"));
    $self->getstatus;
}

sub openretcheck
{
    my $self=shift;
    $self->init;
    $self->con->write(cmd2bin("92 00 02"));
    $self->getstatus;
}

sub zero
{
    my $self=shift;
    my $sum=shift;
    my $summ=splitsum($sum);
    $self->init;
    $self->con->write(cmd2bin("41 00 $summ 00 00 00 10 00"));
    $self->getstatus;
}    

sub zerocheck
{
    my $self=shift;
    $self->init;
    $self->con->write(cmd2bin("59"));
    $self->getstatus;
}    

sub ret
{
    my $self=shift;
    my $sum=shift;
    my $summ=splitsum($sum);
    $self->init;
    $self->con->write(cmd2bin("57 00 $summ 00 00 00 10 00"));
    $self->getstatus;
}    


sub addpay 
{
    my $self=shift;
    my $sum=shift;
    my $sec=shift || '01';
    my $name=shift || 'noname';
    my $summ=splitsum($sum);
    $self->init;
    $self->con->write(cmd2bin("52 03 $summ 00 00 00 10 00 $sec"));
    $self->getstatus;
    $self->init;
    $self->printline($name);
    $self->init;
    $self->con->write(cmd2bin("52 02 $summ 00 00 00 10 00 $sec"));
    $self->getstatus;
    
}

sub closecheck 
{
    my $self=shift;
    my $sum=shift;
    my $type=shift || '01';
    my $summ=splitsum($sum);
    $self->init;
    $self->con->write(cmd2bin("4A 00 $type $summ"));
    $self->getstatus;
}

sub splitsum 
{
    my $sum=shift;
    $sum = sprintf("%011.2f", $sum);
    my (@digs)=$sum=~/(\d\d)(\d\d)(\d\d)(\d\d)\.(\d\d)/;
    return join ' ', @digs;
}

sub mktime {
    my $self = shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year=$year-100;
    $mon++;
    $self->init;
    $self->con->write(cmd2bin("4B $hour $min $sec"));
    $self->getstatus;
    $self->init;
    $self->con->write(cmd2bin("64 $mday $mon $year"));
    $self->getstatus;
}

sub cmd2bin 
{
    my $data=shift;
    my $add=shift;
    my $txt='';
    if (defined $add) {$txt=" ".txt2hex($add)}
    $data="02 00 00 $data$txt";
    my $cmd='';
    foreach my $l (split / /,$data)
    {
        my $hex=hex($l);
        print "$l " if $DEBUG;
        $cmd=$cmd.chr($hex);
    }
    print "\n" if $DEBUG;
    return atol_xor($cmd);
}

sub getstatus
{
    my $self=shift;
    my $msg;
    my $err=-1;
    my ($count,$out)=$self->con->read(1);
    print "get status $count,".ord($out)."\n" if $DEBUG;
    print "sendding 4\n" if $DEBUG;
    $self->con->write("\04");
    ($count,$out)=$self->con->read(1);
    print "sendding 6\n" if $DEBUG;
    $self->con->write("\06");
    while (1) {
        ($count,$out)=$self->con->read(1);
        print "get status $count,".ord($out)."\n" if $DEBUG;
        if (ord($out)==16) {($count,$out)=$self->con->read(1);}
        if (ord($out)==85) {
            ($count,$out)=$self->con->read(1);
            $err=ord($out);
            print "GOT ERROR $err (".geterror($err).") \n" if $DEBUG;
        }
        $msg.=sprintf("%x ", ord($out));
        if (ord($out)==3) {last}
        if ($count==0) {return -1}
    }
    ($count,$out)=$self->con->read(1);
    print "get status $count,".ord($out)."\n" if $DEBUG;
    $self->con->write("\06");
    ($count,$out)=$self->con->read(1);
    return $err;
}

sub regmode {
    my $self=shift;
    $self->init;
    $self->con->write(cmd2bin("56 01 00 00 00 30"));
    $self->getstatus;
}
sub txt2hex 
{
    my $data=shift;
    my $cmd='';
    foreach my $l (split //,$data)
    {
        $cmd=$cmd.sprintf("%x ", ord($l));
    }
    return $cmd;
}

sub atol_xor
{
    my $data=shift;
    my $xor=1;
    my $cmd='';
    foreach my $l (split //,$data)
    {
        $xor=$xor ^ ord($l);
        if (ord($l)==16) {$l=chr(16).$l;$xor=$xor ^ 16}
        if (ord($l)==3) {$l=chr(16).$l;$xor=$xor ^ 16}
        $cmd=$cmd.$l;
    }
    $cmd=$cmd.chr(3).chr($xor);
    print "XOR " if $DEBUG;
    foreach my $l (split //,$cmd){
        printf("%x ", ord($l)) if $DEBUG;
    }
    print "\n" if $DEBUG;
    return $cmd;
}

sub geterror
{
    my $err=shift;
    my $errs={
        0 =>'Ошибок нет',
        1 =>'Контрольная лента обработана без ошибок',
        8 =>'Неверная цена (сумма)',
        10 =>'Неверное количество',
        11 =>'Переполнение счетчика наличности',
        12 =>'Невозможно сторно последней операции',
        13 =>'Сторно по коду невозможно (в чеке зарегистрировано меньшее количество товаров с указанным кодом)',
        14 =>'Невозможен повтор последней операции',
        15 =>'Повторная скидка на операцию невозможна ',
        16 =>'Скидка/надбавка на предыдущую операцию невозможна',
        17 =>'Неверный код товара',
        18 =>'Неверный штрихкод товара',
        19 =>'Неверный формат',
        20 =>'Неверная длина',
        21 =>'ККТ заблокирована в режиме ввода даты',
        22 =>'Требуется подтверждение ввода даты',
        24 =>'Нет больше данных для передачи ПО ККТ',
        25 =>'Нет подтверждения или отмены продажи',
        26 =>'Отчет с гашением прерван. Вход в режим невозможен.',
        27 =>'Отключение контроля наличности невозможно (не настроены необходимые типы оплаты).',
        30 =>'Вход в режим заблокирован',
        31 =>'Проверьте дату и время',
        32 =>'Дата и время в ККТ меньше чем в ЭКЛЗ/ФП',
        33 =>'Невозможно закрыть архив',
        61 =>'Товар не найден',
        62 =>'Весовой штрихкод с количеством <>1.000',
        63 =>'Переполнение буфера чека',
        64 =>'Недостаточное количество товара',
        65 =>'Сторнируемое количество больше проданного',
        66 =>'Заблокированный товар не найден в буфере чека',
        67 =>'Данный товар не продавался в чеке, сторно невозможно',
        68 =>'Memo Plus 3 заблокировано с ПК ',
        69 =>'Ошибка контрольной суммы таблицы настроек Memo Plus',
        70 =>'Неверная команда от ККТ',
        102 =>'Команда не реализуется в данном режиме ККТ',
        103 =>'Нет бумаги',
        104 =>'Нет связи с принтером чеков',
        105 =>'Механическая ошибка печатающего устройства',
        106 =>'Неверный тип чека',
        107 =>'Нет больше строк картинки',
        108 =>'Неверный номер регистра',
        109 =>'Недопустимое целевое устройство',
        110 =>'Нет места в массиве картинок',
        111 =>'Неверный номер картинки / картинка отсутствует',
        112 =>'Сумма сторно больше, чем было получено данным типом оплаты ',
        113 =>'Сумма не наличных платежей превышает сумму чека',
        114 =>'Сумма платежей меньше суммы чека',
        115 =>'Накопление меньше суммы возврата или аннулирования',
        117 =>'Переполнение суммы платежей',
        118 =>'(зарезервировано)',
        122 =>'Данная модель ККТ не может выполнить команду',
        123 =>'Неверная величина скидки / надбавки',
        124 =>'Операция после скидки / надбавки невозможна',
        125 =>'Неверная секция',
        126 =>'Неверный вид оплаты',
        127 =>'Переполнение при умножении',
        128 =>'Операция запрещена в таблице настроек',
        129 =>'Переполнение итога чека',
        130 =>'Открыт чек аннулирования – операция невозможна',
        132 =>'Переполнение буфера контрольной ленты',
        134 =>'Вносимая клиентом сумма меньше суммы чека',
        135 =>'Открыт чек возврата – операция невозможна',
        136 =>'Смена превысила 24 часа',
        137 =>'Открыт чек продажи – операция невозможна',
        138 =>'Переполнение ФП',
        140 =>'Неверный пароль',
        141 =>'Буфер контрольной ленты не переполнен',
        142 =>'Идет обработка контрольной ленты',
        143 =>'Обнуленная касса (повторное гашение невозможно)',
        145 =>'Неверный номер таблицы',
        146 =>'Неверный номер ряда',
        147 =>'Неверный номер поля',
        148 =>'Неверная дата',
        149 =>'Неверное время',
        150 =>'Сумма чека по секции меньше суммы сторно',
        151 =>'Подсчет суммы сдачи невозможен',
        152 =>'В ККТ нет денег для выплаты',
        154 =>'Чек закрыт – операция невозможна',
        155 =>'Чек открыт – операция невозможна',
        156 =>'Смена открыта, операция невозможна',
        157 =>'ККТ заблокирована, ждет ввода пароля доступа к ФП',
        158 =>'Заводской номер уже задан',
        159 =>'Исчерпан лимит перерегистраций',
        160 =>'Ошибка ФП',
        162 =>'Неверный номер смены',
        163 =>'Неверный тип отчета',
        164 =>'Недопустимый пароль',
        165 =>'Недопустимый заводской номер ККТ',
        166 =>'Недопустимый РНМ',
        167 =>'Недопустимый ИНН',
        168 =>'ККТ не фискализирована',
        169 =>'Не задан заводской номер',
        170 =>'Нет отчетов',
        171 =>'Режим не активизирован',
        172 =>'Нет указанного чека в КЛ',
        173 =>'Нет больше записей КЛ',
        174 =>'Некорректный код или номер кода защиты ККТ',
        176 =>'Требуется выполнение общего гашения',
        177 =>'Команда не разрешена введенными кодами защиты ККТ',
        178 =>'Невозможна отмена скидки/надбавки',
        179 =>'Невозможно закрыть чек данным типом оплаты (в чеке присутствуют операции без контроля наличных)',
        180 =>'Неверный номер маршрута',
        181 =>'Неверный номер начальной зоны',
        182 =>'Неверный номер конечной зоны',
        183 =>'Неверный тип тарифа',
        184 =>'Неверный тариф',
        186 =>'Ошибка обмена с фискальным модулем',
        190 =>'Необходимо провести профилактические работы',
        191 =>'Неверные номера смен в ККТ и ЭКЛЗ',
        200 =>'Нет устройства, обрабатывающего данную команду',
        201 =>'Нет связи с внешним устройством',
        202 =>'Ошибочное состояние ТРК',
        203 =>'Больше одной регистрации в чеке',
        204 =>'Ошибочный номер ТРК',
        205 =>'Неверный делитель',
        207 =>'Исчерпан лимит активизаций',
        208 =>'Активизация данной ЭКЛЗ в составе данной ККТ невозможна',
        209 =>'Перегрев головки принтера',
        210 =>'Ошибка обмена с ЭКЛЗ на уровне интерфейса I2C',
        211 =>'Ошибка формата передачи ЭКЛЗ',
        212 =>'Неверное состояние ЭКЛЗ',
        213 =>'Неисправимая ошибка ЭКЛЗ',
        214 =>'Авария крипто-процессора ЭКЛЗ',
        215 =>'Исчерпан временной ресурс ЭКЛЗ',
        216 =>'ЭКЛЗ переполнена',
        217 =>'В ЭКЛЗ переданы неверная дата или время',
        218 =>'В ЭКЛЗ нет запрошенных данных',
        219 =>'Переполнение ЭКЛЗ (итог чека)',
        220 =>'Буфер переполнен',
        221 =>'Невозможно напечатать вторую фискальную копию',
        222 =>'Требуется гашение ЭЖ',
        223 =>'Сумма налога больше суммы регистраций по чеку и/или итога или больше суммы регистрации',
        224 =>'Начисление налога на последнюю операцию невозможно',
        225 =>'Неверный номер ЭКЛЗ',
        228 =>'Сумма сторно налога больше суммы зарегистрированного налога данного типа',
        229 =>'Ошибка SD',
        230 =>'Операция невозможна, недостаточно питания'
    };
    return $errs->{$err};
}


1
__END__
